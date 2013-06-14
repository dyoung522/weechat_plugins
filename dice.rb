# Donovan C. Young <dyoung522@gmail.com> # http://www.DonovanYoung.com
# (See below for LICENSE.)
#
# Thanks To Mahlon E. Smith <mahlon@martini.nu>
#   I used his amqp_notify.rb script as a ruby example for weechat script coding.  So, thank you Mahlon!
#
# Dice
# ----
#
# Rolls a set of dice as provided, returning the result.
#
# Install instructions:
# ---------------------
#
#   Load into Weechat like any other script, after putting it into
#   your ~/.weechat/ruby directory:
#
#        /ruby load dice.rb
#
# Options:
# --------
#
#   plugins.var.ruby.dice.enabled
#
#       A global on/off toggle.
#       Default: "on"
#
#   plugins.var.ruby.dice.dice
#
#       The default dice set to use when none are given
#       Default: "2d10%" (2d10 in percentage format)
#
#   plugins.var.ruby.dice.auto_respond
#
#       Should we auto-respond to !roll from others (bot-like action)?
#       Default: "off"
#
#   plugins.var.ruby.dice.auto_respond_when_away
#
#       If auto_respond is enabled, should we still respond while we're marked away?
#       Default: "off"
#
#   plugins.var.ruby.dice.auto_respond_trigger
#
#       The command we should listen for and auto_respond to
#       Default: "!roll"
#
#   plugins.var.ruby.dice.ignore_nicks
#
#       Comma separated list of nicks to ignore in buffer input (only useful if auto_respond is true)
#       Default: ""
#
#   plugins.var.ruby.dice.ignore_channels
#
#       Comma separated list of channels to ignore in buffer input (only useful if auto_respond is true)
#       Default: ""
#

### Code stolen from: Mahlon E. Smith
### Convenience 'truth' module for Weechat config strings, because:
###
###     self.enabled.true?
###
### reads a whole lot nicer than:
###
###     Weechat.config_string_to_boolean(Weechat.config_get_plugin('enabled')) == "1"
###
### I resist the temptation to monkeypatch all of String during my
### time with Weechat.  Heh.
###
module Truthy
    def true?
        return Weechat.config_string_to_boolean( self.to_s ).to_i.zero? ? false : true
    end
end
### End of stolen code

### The actual Weechat script.
###
class Dice
    include Weechat

    PROGNAME = 'Dice'
    VERSION = '1.7'
    DEBUG = true

    ## Register component
    SIGNATURE = [
            PROGNAME,
            'Donovan C. Young',
            VERSION,
            'GPL3',
            'Rolls the set of dice provided, sending results to the active buffer.',
            'weechat_unload',
            'UTF-8'
    ]

    ## Roll command component
    COMMAND_ROLL = [
            'roll',
            'Generates a random result based upon the given dice set',
            '[dice]',
            "dice:   die set to roll using the following syntax: #d#[+-#|%]\n\n" +
            "        The first # is an integer representing the number of dice to use followed by a literal 'd'" +
                     "  (If not provided a 1 will be presumed).\n" +
            "        The next # represents the sides of each dice followed by an optional modifier.\n" +
            "        - Modifiers can be a + or - followed by an integer." +
                    "  This number will be added or subtracted after the random roll is generated\n" +
            "        - Alternatively, a literal '%' may be used to indicate you wish a percentage roll" +
                    "  (only valid for 2d10 or d100)\n\n" +
            "        If no dice are provided, the default set from the options will be used\n",
            '',
            'rollem',
            ''
    ]

    DEFAULT_OPTIONS = {
            :enabled                => [ 'on'   , 'Enable to Disable this plugin' ],
            :die                    => [ '2d10' , 'The default die set to use' ],
            :auto_respond           => [ 'off'  , 'Should we auto respond to trigger command?' ],
            :auto_respond_when_away => [ 'off'  , 'Should we auto respond when away?' ],
            :auto_respond_trigger   => [ '!roll', 'The command we should listen for -- be careful what you use!' ],
            :ignore_nicks           => [ ''     , 'comma separated list of nicks to ignore when auto responding' ],
            :ignore_channels        => [ ''     , 'comma separated list of channels to ignore when auto responding' ]
    }


    ### Prepare configuration and begin listening for events
    ###
    def initialize

        DEFAULT_OPTIONS.each_pair do |option, value_array|

            (value, desc) = value_array

            # install default options if needed.
            #
            if Weechat.config_is_set_plugin( option.to_s ).zero?
                self.print_info "Setting value '%s' to %p" % [ option, value ] if DEBUG
                Weechat.config_set_plugin( option.to_s, value.to_s )
                Weechat.config_set_desc_plugin( option.to_s, desc.to_s )
            end

            # read in existing config values, attaching
            # them to instance variables.
            #
            val = Weechat.config_get_plugin( option.to_s )
            val.extend( Truthy )
            instance_variable_set( "@#{option}".to_sym, val )
            self.class.send( :attr, option.to_sym, true )
        end

        self.print_info "#{PROGNAME} v.#{VERSION} loaded"
        self.print_info "The die is cast, we're ready to /roll!"
    end


    ########################################################################
    ### W E E C H A T   H O O K S
    ########################################################################

    ### Validate values for config changes, and take appropriate action
    ### on any changes that immediately require it.
    ###
    def config_changed( data, option, new_value )
        option = option.match( /\.(\w+)$/ )[1]
        new_value.extend( Truthy )
        self.print_info "Setting value '%s' to %p" % [ option, new_value ] if DEBUG
        instance_variable_set( "@#{option}".to_sym, new_value )
        return WEECHAT_RC_OK
    end


    ### Process all incoming messages, filtering out anything we're not
    ### interested in seeing.
    ###
    def check_buffer( data, buffer, date, tags, visible, highlight, prefix, message )

        return WEECHAT_RC_OK unless self.enabled.true?
        return WEECHAT_RC_OK unless self.auto_respond.true?

        # Build our ignore filters array (depending on if multiple enteries were given)
        filter_nicks = self.ignore_nicks =~ /,/ ? self.ignore_nicks.split(',') : [ self.ignore_nicks ]
        filter_channels = self.ignore_channels =~ /,/ ? self.ignore_channels.split(',') : [ self.ignore_channels ]

        # Build tags array
        tags = tags.split(',')

        #if DEBUG
        #    self.print_info "DATA: #{data}"
        #    self.print_info "DATE: #{date}"
        #    self.print_info "visible: #{visible}"
        #    self.print_info "highlight: #{highlight}"
        #    self.print_info "prefix: #{prefix}"
        #    self.print_info "message: #{message}"
        #    self.print_info "TAGS: #{tags}"
        #    self.print_info "filters: Nicks:    #{filter_nicks}"
        #    self.print_info "         Channels: #{filter_channels}"
        #end

        return WEECHAT_RC_OK unless tags[0] == 'irc_privmsg'

        # Should we respond when away?
        away = (Weechat.buffer_get_string( buffer, "localvar_away" )).empty? ? false : true
        return WEECHAT_RC_OK if away && !self.auto_respond_when_away.true?

        # Look for the trigger
        if message =~ /^#{self.auto_respond_trigger}\b/

            # Are we specifically ignoring this user?
            filter_nicks.each do |filter|
                next if filter.empty?
                if prefix =~ /#{filter}/i
                    self.print buffer, "Ignorning autoroll request from %s (matching %s)" % [ prefix, filter ] if DEBUG
                    return WEECHAT_RC_OK
                end
            end

            # GTG - Roll 'em
            dice = message.split[1] || self.die

            self.print buffer, "Auto-Rolling %s" % [ dice ]

            roll = self.roll_die( dice, buffer )
            Weechat.command( buffer, roll ) if roll
        end

        return WEECHAT_RC_OK

    rescue => err
        self.disable "%s, %s" % [ err.class.name, err.message ] unless DEBUG
        return WEECHAT_RC_OK
    end


    ### Roll random dice
    ###
    def rollem( data, buffer, dice )
        return WEECHAT_RC_OK unless self.enabled.true?

        roll = self.roll_die( dice, buffer )
        Weechat.command( Weechat.current_buffer(), roll ) if roll

        return WEECHAT_RC_OK
    end

    ########################################################################
    ### I N S T A N C E   M E T H O D S
    ########################################################################

    def roll_die( diceset, buffer )
        diceset = self.die if diceset.empty?
        buffer ||= Weechat.current_buffer()
        score_message = ''
        score = 0

        set = diceset.match( /(\d*)d(\d*)(([+-]\d+)|(%))?/ )
        if set.nil?
            self.print buffer, "Invalid dice set recieved: #{diceset}"
            return
        end

        # parse parameters
        ( throws, sides, modifier ) = set[1..3]

        # Parse modifier into it's components
        if modifier
            op = modifier[0]
            mod = modifier[1..-1].to_i
        end

        # Validate and convert all arguments into integers (when appropriate)
        throws = throws.to_i
        throws = 1 if throws <= 0
        if throws > 100
            self.print buffer, "Too many throws, try a number between 1 and 100"
            return
        end

        sides  = sides.to_i
        sides  = 100 if sides <= 0
        if sides > 1000000
            self.print buffer, "You're crazy, I'm not going to do that."
            return
        end

        # Print a message only to the local screen, describing what we're about to do
        self.print buffer, "Rolling %i of d%i %s" % [ throws, sides, modifier ]

        # Generate the random rolls
        results = throws.times.map{ 1 + Random.rand(sides) }

        # Generate percentage roll or add modifier as needed
        if op == '%' && ( ( throws == 2 && sides == 10 ) || ( throws == 1 && sides === 100 ) )
            if ( throws == 2 )
                score = ( (results[0]*10) + results[1] ).to_s + '%'
                score_message = "#{results[0]}+#{results[1]}"
            else
                score = results[0].to_s + '%'
            end
        else    # Just add the results together
            results.each do |num|
                score += num
                score_message += "+#{num}"
            end
            # Remove the very first OP symbol
            score_message = score_message[1..-1]

            # Add the modifier, when provided
            if op =~ /[+-]/
                score = eval("#{score}#{op}#{mod}")
                score_message = "(#{score_message})#{op}#{mod}"
            end
        end
        # Format the final message back to the buffer
        score_message += "%s%s" % [ ( op == '%' && throws == 1 ) ? '' : '= ', score ]

        # Return the result string
        return score_message
    end

    ### Disable the plugin on repeated error.
    ###
    def disable( reason )
        self.print_info "Disabling plugin due to error: %s" % [ reason ]
        Weechat.config_set_plugin( 'enabled', 'off' )
    end


    #########
    protected
    #########

    ### Quick wrapper for sending info messages to the weechat main buffer.
    ###
    def print_info( msg )
        Weechat.print '', "%sDICE\t%s" % [ Weechat.color('yellow'), msg ]
    end

    def print( buffer, msg )
        Weechat.print buffer, "%s***\t%s%s" % [ Weechat.color('yellow'), Weechat.color('white'), msg ]
    end
end



### Weechat entry point.
###
def weechat_init
    require 'rubygems'

    Weechat::register *Dice::SIGNATURE
    $dice = Dice.new

    Weechat.hook_command *Dice::COMMAND_ROLL
    Weechat.hook_config( 'plugins.var.ruby.dice.*', 'config_changed', '' )
    Weechat.hook_print( '', '', '', 1, 'check_buffer', '' )

    return Weechat::WEECHAT_RC_OK

rescue LoadError => err
    Weechat.print '', "dice: %s, %s\n$LOAD_PATH: %p" % [
            err.class.name,
            err.message,
            $LOAD_PATH
    ]
    Weechat.print '', 'dice: Unable to initialize due to missing dependencies.'
    return Weechat::WEECHAT_RC_ERROR
end

### Hook for manually unloading this script.
###
def weechat_unload
    Weechat.unhook_all()
    return Weechat::WEECHAT_RC_OK
end


### Allow Weechat namespace callbacks to forward to the Roledice object.
###
require 'forwardable'
extend Forwardable
def_delegators :$dice, :check_buffer, :config_changed, :rollem

__END__
__LICENSE__

Copyright (c) 2013, Donovan C. Young <dyoung522@gmail.com>

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this
      list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright notice, this
      list of conditions and the following disclaimer in the documentation and/or
      other materials provided with the distribution.

    * Neither the name of the author, nor the names of contributors may be used to
      endorse or promote products derived from this software without specific prior
      written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

