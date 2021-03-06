# :include: ../rdoc/patternformatter
#
# == Other Info
#
# Version:: $Id: patternformatter.rb,v 1.2 2002/01/28 16:05:05 cepheus Exp $
# Author::  Leon Torres <leon@ugcs.caltech.edu>

require "log4r/formatter/formatter"

module Log4r
  # See log4r/formatter/patternformatter.rb
  class PatternFormatter < BasicFormatter

    # Arguments to sprintf keyed to directive letters
    DirectiveTable = {
      "c" => 'event.name',
      "C" => 'event.fullname',
      "d" => 'format_date',
      "t" => 'event.tracer[0]',
      "m" => 'event.data',
      "M" => 'format_object(event.data)',
      "l" => 'LNAMES[event.level]',
      "z" => 'Log4r::Logger::NDC.peek()',
      "y" => 'Log4r::Logger::NDC.dotted()',
      "g" => 'Log4r::Logger.GDC',
      "x" => 'Log4r::Logger::NDC::get',
      "%" => '"%"'
    }

    # Matches the first directive encountered and the stuff around it.
    #
    # * $1 is the stuff before directive or "" if not applicable
    # * $2 is the directive group or nil if there's none
    # * $3 is the %#.# match within directive group
    # * $4 is the .# match which we don't use (it's there to match properly)
    # * $5 is the directive letter
    # * $6 is optional parm to the directive, wrapped in {}.  currently used for z only
    # * $7 is internals of the optional parm to the directive.  currently used for z only
    # * $8 is the stuff after the directive or "" if not applicable

    DirectiveRegexp = /([^%]*)((%-?\d*(\.\d+)?)([cCdtmMlxygz%]))?({([^}]*)})?(.*)/

    # default date format
    ISO8601 = "%Y-%m-%d %H:%M:%S"

    attr_reader :pattern, :date_pattern, :date_method

    # Accepts the following hash arguments (either a string or a symbol):
    #
    # [<tt>pattern</tt>]         A pattern format string.
    # [<tt>date_pattern</tt>]    A Time#strftime format string. See the
    #                            Ruby Time class for details.
    # [+date_method+]
    #   As an option to date_pattern, specify which
    #   Time.now method to call. For
    #   example, +usec+ or +to_s+.
    #   Specify it as a String or Symbol.
    #
    # The default date format is ISO8601, which looks like this:
    #
    #   yyyy-mm-dd hh:mm:ss    =>    2001-01-12 13:15:50

    def initialize(hash={})
      super(hash)
      @pattern = (hash['pattern'] or hash[:pattern] or nil)
      @date_pattern = (hash['date_pattern'] or hash[:date_pattern] or nil)
      @date_method = (hash['date_method'] or hash[:date_method] or nil)
      @date_pattern = ISO8601 if @date_pattern.nil? and @date_method.nil?
      PatternFormatter.create_format_methods(self)
    end

    # PatternFormatter works by dynamically defining a <tt>format</tt> method
    # based on the supplied pattern format. This method contains a call to
    # Kernel#sptrintf with arguments containing the data requested in
    # the pattern format.
    #
    # How is this magic accomplished? First, we visit each directive
    # and change the %#.# component to  %#.#s. The directive letter is then
    # used to cull an appropriate entry from the DirectiveTable for the
    # sprintf argument list. After assembling the method definition, we
    # run module_eval on it, and voila.

    def PatternFormatter.create_format_methods(pf) #:nodoc:
      # first, define the format_date method
      if pf.date_method
        module_eval "def pf.format_date; Time.now.#{pf.date_method}; end"
      else
        define_method(:format_date) do
          n = Time.now
          us = n.usec.to_s[0,3]
          %Q[#{n.strftime "#{pf.date_pattern}"},#{us}]
        end
      end
      # and now the main format method
      ebuff = "def pf.format(event)\n sprintf(\""
      _pattern = pf.pattern.dup
      args = [] # the args to sprintf which we'll append to ebuff lastly
      while true # work on each match in turn
        match = DirectiveRegexp.match _pattern
        ebuff += match[1] unless match[1].empty?
        break if match[2].nil?
        # deal with the directive by inserting a %#.#s where %#.# is copied
        # directy from the match
        ebuff += match[3] + "s"
        if match[7].nil? || match[7].empty?
          args << DirectiveTable[match[5]] # cull the data for our argument list
        else
          args << %Q[#{DirectiveTable[match[5]]}(#{match[7]})] # cull the data for our argument list
        end
        break if match[8].empty?
        _pattern = match[8]
      end
      ebuff += '\n", ' + args.join(', ') + ")\n"
      ebuff += "end\n"
      module_eval ebuff
    end
  end
end
