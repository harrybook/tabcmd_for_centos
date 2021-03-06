# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2010 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
#
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------
# static_asset_version.rb
# -----------------------------------------------------------------------

# -----------------------------------------------------------------------
# This file contains support for versioning reference to static assets,
# where static assets are files of type <css, gif, jpg, js, png>, located
# in the source tree underneath wgserver/public and vizqlserver/public
#
# The versioning occurs by recursively copying the contents of these public directories,
# into a versioned directory.
#
# Before:  public
#             images
#             javascripts
#
# After:
#          public
#             images
#             javascripts
#             v_60001101261612
#                images
#                javascripts
#
# Note that the versioned directory is not checked into source control.  It is a build/deploy/install artifact only
# The original static assets are left untouched.  .p4ignores has entries for the versioned directory pattern
#
# That versioned directory is then referenced by the Rails Apps,
# html-files, and javascripts via a combination of monkey-patching Rails's asset_tag helpers and
# our own new get_content_url (wg) and getAssetUrl(vizql/js) helpers
#
# The installer copies from most recent versioned directory via an innosetup snippet file created here
# that is included into the base installer.  More details on that below
#
#
# This objects and methods in this file are typically invoked by a rake task.
# @see rake static_asset_version:run, which is called by the existing 'rake deploy' task.
#
#
# -----------------------------------------------------------------------

require 'tempfile'
require 'product_version'
require 'static_asset_exception'

#we do this dynamically, so that if the dll isn't there when this file is first
#required, it will still work
autoload :VizqlDll, 'tabvizql'

#### helper class for running outside of rake environment
class BogusLogger
  def initialize
  end

  def method_missing(method, *args)
    puts *args
  end
end




# ---------------------------------------------------------------------------------------------------
class StaticAssetVersion

  INI_TEMPLATE = %Q{
;############################################################################
;# DO NOT EDIT THIS AUTOGENERATED FILE.
;# This file should not be checked in to source control, it is a build artifact (for developers it is a deploy artifact)
;#
;# This file contains intaller directives to copy the versioned directories below wgapp/public and vizqlserver/public
;#
;# see http://wiki/bin/view/Development/BrowserCacheManagementForStaticAssets
;#
[static_assets]
version=$VERSION$
}

  ISS_TEMPLATE = %Q{
;############################################################################
;# DO NOT EDIT THIS AUTOGENERATED FILE.
;# This file should not be checked in to source control, it is a build artifact (for developers it is a deploy artifact)
;#
;# This file contains intaller directives to copy the versioned directories below wgapp/public and vizqlserver/public
;#
;# see http://wiki/bin/view/Development/BrowserCacheManagementForStaticAssets
;#
[CustomMessages]
static_asset_Version=$VERSION$
}

  ABANDONED_ISS_TEMPLATE = %Q[
;############################################################################
;# DO NOT EDIT THIS AUTOGENERATED FILE.
;# This file should not be checked in to source control, it is a build artifact (for developers it is a deploy artifact)
;#
;# This file contains intaller directives to copy the versioned directories below wgapp/public and vizqlserver/public
;#
;# see http://wiki/bin/view/Development/BrowserCacheManagementForStaticAssets
;#
Source: "workgroup\\wgapp\\public\\$VERSION$\\*";                           DestDir: "{app}\\{cm:Version}\\wgserver\\public\\$VERSION$"; Excludes: "javascripts\\lytebox\\*,images\\server-logo.gif,images\\tableau-icon.gif"; Flags: ignoreversion recursesubdirs
Source: "workgroup-support\\lytebox\\*";                        DestDir: "{app}\\{cm:Version}\\wgserver\\public\\$VERSION$\\javascripts\\lytebox\\"; Flags: ignoreversion recursesubdirs
; OEM-customizable images
Source: "{#SourceDirWorkgroupBranding}\\wgapp\\public\\$VERSION$\\images\\server-logo.gif";    DestDir: "{app}\\{cm:Version}\\wgserver\\public\\$VERSION$\\images"; Flags: ignoreversion
Source: "{#SourceDirWorkgroupBranding}\\wgapp\\public\\$VERSION$\\images\\tableau-icon.gif";   DestDir: "{app}\\{cm:Version}\\wgserver\\public\\$VERSION$\\images"; Flags: ignoreversion
Source: "workgroup\\vqlweb\\public\\$VERSION$\\*";                          DestDir: "{app}\\{cm:Version}\\vizqlserver\\public\\$VERSION$"; Excludes: "javascripts\\*"; Flags: ignoreversion recursesubdirs
Source: "workgroup\\vqlweb\\public\\$VERSION$\\javascripts\\*";              DestDir: "{app}\\{cm:Version}\\vizqlserver\\public\\$VERSION$\\javascripts\\"; Flags: ignoreversion
Source: "workgroup-support\\lytebox\\*";                        DestDir: "{app}\\{cm:Version}\\vizqlserver\\public\\$VERSION$\\javascripts\\lytebox\\"; Flags: ignoreversion recursesubdirs
Source: "workgroup\\install\\dojo-vqlweb\\*";                    DestDir: "{app}\\{cm:Version}\\vizqlserver\\public\\$VERSION$\\javascripts\\"; Flags: ignoreversion recursesubdirs
]
  ISS_FILE_NAME = "static_asset_version.iss"
  INI_FILE_NAME = "static_asset_version.ini"

  INSTALLER_TEMPLATE_FILE_NAME = "Setup-Workgroup-exerb-1.0.iss.tmpl"
  INSTALLER_DESTINATION_FILE_NAME = "Setup-Workgroup-exerb-1.0.iss"

  attr_reader :asset_version, :config_name, :logger, :dry_run, :verbose, :manual_version, :iss_file_path, :ini_file_path, :roots

  VERSION_PREFIX = 'v_'
  BASE_VERSION_NAME = "base"

  def initialize(opts = {})
    puts "opts[:version] is #{opts[:version]}" if verbose

    defaults = {:logger => nil, :dry_run => false, :verbose => false, :config_name => 'dev'}
    args = defaults.merge(opts)

    @config_name = args[:config_name]

    @dry_run = args[:dry_run]

    @logger = args[:logger]
    @logger ||= BogusLogger.new()

    @verbose = args[:verbose]
    @iss_file_path = %Q[#{File.join(File.dirname(__FILE__), ISS_FILE_NAME)}]
    @ini_file_path = %Q[#{File.join(File.dirname(__FILE__), INI_FILE_NAME)}]

    if opts[:version]
      @asset_version = opts[:version]
      if !@asset_version.match(%r{^#{VERSION_PREFIX}})
        @asset_version = VERSION_PREFIX + @asset_version
      end
      @manual_version = true
    else
      @asset_version = VERSION_PREFIX + automated_version_string_or_base_version
      @manual_version = false
    end
    puts "Asset_Version is #{asset_version}, obtained #{manual_version ? 'manually' : 'automatically'}" if verbose

    @roots = []
  end

  def automated_version_string_or_base_version
    configuration_name ||= ENV["WG_SERVICE"] || ENV["WG_TEST_SERVICE"] || java.lang.System.get_property("wgserver.service")

    compiled_version_string = VizqlDll::Vizql.GetAppBuildVersion()
    pieces = compiled_version_string.split('.')

    ## Case 39759:  always return 'v_base' when running tests.  Build machines will have a real version string but only v_base directory
    if ('test' == configuration_name) || ((0 == pieces[1].to_i) && (0 == pieces[2].to_i) && (0 == pieces[3].to_i))
      return BASE_VERSION_NAME
    else
      return pieces.join('')
    end
  end

  def self.base_version_name
    return VERSION_PREFIX + BASE_VERSION_NAME
  end

private

  ## This step only makes sense for developers/builders
  def setup_for_config
    @roots = [File.join(File.dirname(__FILE__), "../wgapp"), File.join(File.dirname(__FILE__), "../vqlweb")]
  end

  ## Innosetup can't reference variables in the files section of an iss file.  So, we write a small iss snippet that gets
  ## included into the larger iss file instead of using variables.
  def write_installer_files
    unless dry_run
      f = File.open(iss_file_path, 'w')
      f.write(ISS_TEMPLATE.gsub('$VERSION$',asset_version))
      f.write("\n")
      f.write(%Q[;This file autogenerated on #{Time.now.utc} (localtime = #{Time.now.to_s})\n])
      f.write(%Q[;The version "#{asset_version}" was #{manual_version ? 'manually' : 'automatically'} obtained\n])
      f.close()

      f = File.open(ini_file_path, 'w')
      f.write(INI_TEMPLATE.gsub('$VERSION$',asset_version))
      f.write("\n")
      f.write(%Q[;This file autogenerated on #{Time.now.utc} (localtime = #{Time.now.to_s})\n])
      f.write(%Q[;The version "#{asset_version}" was #{manual_version ? 'manually' : 'automatically'} obtained\n])
      f.close()
    end
  end


  ## decide which strategy to use
  def make_versioned_directories
    make_versioned_directories_by_linking
  end

  ## If we can convince innosetup to ignore what could be recursive chaos by placing a symlink to a parent inside the parent
  ## this strategy involves much less copying
  def make_versioned_directories_by_linking
    leaves = ['v_base']
    roots.each do |root|
      leaves.each do |leaf|
        linkname = File.join(root,'public',asset_version).gsub('/','\\')
        sourcename = File.join(root,'public',leaf).gsub('/','\\')
        if !File.exists?(linkname)
          command = %Q[cmd /C mklink /D #{linkname} #{sourcename}] #windows link command is dest,source.  GRR!
          logger.debug("executing #{command}") if verbose
          result = `#{command}`
          logger.debug("result is #{result}") if verbose
        else
          logger.debug("not creating link #{linkname} to #{sourcename} as a file by that name already exists") if verbose
        end
      end
    end
  end


  ## otoh, innosetup maybe copying is what we need to do...
  def make_versioned_directories_by_copying
    leaves = ['public']

    roots.each do |root|
      leaves.each do |leaf|
        base_path = File.join(root, leaf)
        versioned_path = File.join(base_path, asset_version)
        # we need a peer path so that we don't get caught up in the recursive copy.
        versioned_peer_path = File.join(root, "#{leaf}_#{asset_version}")

        logger.debug("making versioned peer for copy #{versioned_peer_path}")
        unless dry_run
          if File.exists?(versioned_peer_path)
            if !File.directory?(versioned_peer_path)
              raise StaticAssetException.new("#{versioned_peer_path} exists but is not a directory.")
            else
              logger.debug("#{versioned_peer_path} already exists") if verbose
            end
          else
            FileUtils.mkdir(versioned_peer_path)
            raise StaticAssetException.new("unable to create versioned directory #{versioned_peer_path}") unless
              File.exists?(versioned_peer_path)
          end
        end

        if File.exists?(versioned_path)
          logger.debug("#{versioned_path} already exists, trying to delete it") if verbose
          unless dry_run
            FileUtils.rm_r(versioned_path, :force => true)
            if File.exists?(versioned_path)
              raise StaticAssetException.new("unable to delete #{versioned_path}")
            end
          end
        end

        if File.exists?(versioned_peer_path)
          logger.debug("#{versioned_peer_path} already exists, trying to delete it") if verbose
          unless dry_run
            FileUtils.rm_r(versioned_peer_path, :force => true)
            if File.exists?(versioned_peer_path)
              raise StaticAssetException.new("unable to delete #{versioned_peer_path}")
            end
          end
        end

        # note we do the recursive copy using the 'src/.' idiom, to avoid ending up with dest/src.
        # we want everything under src to be copied to dest
        logger.debug("recursive copy of #{base_path + '/.'} to #{versioned_path}")
        FileUtils.cp_r(File.join(base_path,'/.'), versioned_peer_path) unless dry_run

        logger.debug("moving #{versioned_peer_path} to #{versioned_path}")
        FileUtils.mv(versioned_peer_path, versioned_path, :force => true) unless dry_run
      end
    end
  end


public

  ## external entry point
  def version_static_assets!
    setup_for_config
    write_installer_files
  end

  ## external entry point
  def version_static_assets_for_builder!
    setup_for_config
    write_installer_files
    make_versioned_directories
  end


end


#   def test_harness
#      sav = StaticAssetVersion.new(:config_name => 'bogus', :verbose => true, :version => "moose")
#      sav.version_static_assets!
#    end
#   test_harness()

