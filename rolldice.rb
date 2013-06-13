# vim: set noet nosta sw=4 ts=4 :
#
# Donovan C. Young <dyoung522@gmail.com>
# http://www.DonovanYoung.com
# (See below for LICENSE.)
#
# Thanks To Mahlon E. Smith <mahlon@martini.nu>
#   I used his amqp_notify.rb script as a ruby example for weechat script coding.  So, thank you Mahlon!
#
# Rolldice
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
#        /ruby load amqp_notify.rb
#
# Options:
# --------
#
#   plugins.var.ruby.rolldice.enabled
#
#       A global on/off toggle.
#       Default: "on"
#
#   plugins.var.ruby.rolldice.dice
#
#       The default dice set to use when none are given
#       Default: "2d10%" (2d10 in percentage format)
#
#   plugins.var.ruby.rolldice.auto_respond
#
#       Should we auto-respond to !roll from others (bot-like action)?
#       Default: "off"
#
#   plugins.var.ruby.rolldice.auto_respond_when_away
#
#       If auto_respond is enabled, should we still respond while we're marked away?
#       Default: "off"
#
#   plugins.var.ruby.rolldice.auto_respond_trigger
#
#       The command we should listen for and auto_respond to
#       Default: "!roll"
#
#   plugins.var.ruby.rolldice.ignore_filter
#
#       Comma separated list of regex to ignore in buffer input (only useful if auto_respond is true)
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
class Rolldice
    include Weechat

    DEBUG = false

    SIGNATURE = [
            'roll',
            'Donovan C. Young',
            '0.1',
            'BSD',
            'Rolls the set of dice provided, sending results to the active buffer.',
            '',
            'UTF-8'
    ]

    ### Default Options
    DEFAULT_OPTIONS = {
            :enabled                => 'on',
            :die                    => '2d10%',
            :auto_respond           => 'off',
            :auto_respond_when_away => 'off',
            :auto_respond_trigger   => '!roll',
            :ignore_filter          => ''
    }


    ### Prepare configuration and begin listening for events
    ###
    def initialize

        DEFAULT_OPTIONS.each_pair do |option, value|

            # install default options if needed.
            #
            if Weechat.config_is_set_plugin( option.to_s ).zero?
                self.print_info "Setting value '%s' to %p" % [ option, value ] if DEBUG
                Weechat.config_set_plugin( option.to_s, value.to_s )
            end

            # read in existing config values, attaching
            # them to instance variables.
            #
            val = Weechat.config_get_plugin( option.to_s )
            val.extend( Truthy )
            instance_variable_set( "@#{option}".to_sym, val )
            self.class.send( :attr, option.to_sym, true )
        end

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

        case option
            # Dynamically enable/disable the script
            when 'enabled'
                self.enabled = new_value
                new_value.true? ? self.bind : self.unbind

            # ... just change the setting, no validation/action needed.
            else
                instance_variable_set( "@#{option}".to_sym, new_value )
        end

        return WEECHAT_RC_OK
    end


    ### Process all incoming messages, filtering out anything we're not
    ### interested in seeing.
    ###
    def notify_msg( data, buffer, date, tags, visible, highlight, prefix, message )

        return WEECHAT_RC_OK unless self.enabled.true?
        return WEECHAT_RC_OK unless self.auto_respond.true?

        # Should we respond when away?
        away = (Weechat.buffer_get_string( buffer, "localvar_away" )).empty? ? false : true
        return WEECHAT_RC_OK unless away && self.auto_respond_when_away.true?

        # Are we specifically ignoring this message?
        filters = self.ignore_filter.split( ',' )

        return WEECHAT_RC_OK if filters.empty?
        filters.each.to_s do |filter|
            if message =~ /#{filter}/
                self.print_info "Ignorning %s" % [ filter ] if DEBUG
                return WEECHAT_RC_OK
            end
        end

        # Look for the trigger
        if messages =~ /^#{self.auto_respond_trigger}\s/
            self.print_info( self.roll_die messages.split[1] )
        end

        return WEECHAT_RC_OK

    rescue => err
        self.disable "%s, %s" % [ err.class.name, err.message ]
        return WEECHAT_RC_OK
    end


    ########################################################################
    ### I N S T A N C E   M E T H O D S
    ########################################################################

    ### Connect to the RabbitMQ broker.
    ###
    def roll_die
        return unless self.enabled.true?
        self.print_info "The die roll goes here"

        return WEECHAT_RC_OK
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
        Weechat.print '', "%sROLL\t%s" % [
                Weechat.color('yellow'),
                msg
        ]
    end
end



### Weechat entry point.
###
def weechat_init
    #require 'rubygems'

    Weechat::register *Rolldice::SIGNATURE
    $dice = Rolldice.new
    Weechat.hook_print( '', '', '', 1, 'notify_msg', '' )
    Weechat.hook_config( 'plugins.var.ruby.rolldice.*', 'config_changed', '' )

    return Weechat::WEECHAT_RC_OK

rescue LoadError => err
    Weechat.print '', "rolldice: %s, %s\n$LOAD_PATH: %p" % [
            err.class.name,
            err.message,
            $LOAD_PATH
    ]
    Weechat.print '', 'rolldice: Unable to initialize due to missing dependencies.'
    return Weechat::WEECHAT_RC_ERROR
end

__END__
__LICENSE__

Copyright (c) 2011, Mahlon E. Smith <mahlon@martini.nu>

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

