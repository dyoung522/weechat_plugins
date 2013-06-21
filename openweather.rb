# Donovan C. Young <dyoung522@gmail.com> # http://www.DonovanYoung.com
# (See below for LICENSE.)
#
#
# OpenWeather
# -----------
#
#   OpenWeather provides a current weather conditions for the given city
#   using the free open-source weather API from openweathermap.com
#
#
# Install instructions:
# ---------------------
#
#   Load into Weechat like any other script, after putting it into
#   your ~/.weechat/ruby directory:
#
#        /ruby load openweather.rb
#
# Options:
# --------
#
#   plugins.var.ruby.openweather.default_city
#
#       Default city to pull weather conditions
#       (this will be set on first run if blank)
#
#   plugins.var.ruby.openweather.units
#
#       Units of measure to use, may be imperial or metric
#

$PROGNAME    = 'OpenWeather'
$AUTHOR      = 'Donovan C. Young'
$VERSION     = '1.2.1'
$DESCRIPTION = 'Provides current weather forecast using api.openweathermap.com'

### The actual Weechat script.
###
class OpenWeather
    include Weechat

    # true or false
    DEBUG = true

    ## Register component
    SIGNATURE = [
            $PROGNAME.downcase,
            $AUTHOR,
            $VERSION,
            'GPL3',
            $DESCRIPTION,
            'weechat_unload',
            'UTF-8'
    ]

    ## Roll command component
    COMMAND = [
            'weather',
            'Displays current weather conditions',
            '[city]',
            "city:   The city to obtain weather information for, may also include two character state code (e.g. Atlanta,GA)\n\n",
            '',
            'weather',
            ''
    ]

    # Set options and their defaults here
    DEFAULT_OPTIONS = {
            :default_city => [ ''        , 'The default city to pull forecast information from, will be set on first run if blank.'],
            :units        => [ 'imperial', 'The unit of measure to use; may be "imperial", or "metric"'],
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
            instance_variable_set( "@#{option}".to_sym, val )
            self.class.send( :attr, option.to_sym, true )
        end

        self.print_info "#{$PROGNAME} v.#{$VERSION} loaded"
    end


    ########################################################################
    ### W E E C H A T   C A L L B A C K S
    ########################################################################

    ### Validate values for config changes, and take appropriate action
    ### on any changes that immediately require it.
    ###
    def config_changed_cb( data, option, new_value )
        option = option.match( /\.(\w+)$/ )[1]
        self.print_info "Setting value '%s' to %p" % [ option, new_value ] if DEBUG
        instance_variable_set( "@#{option}".to_sym, new_value )
        return WEECHAT_RC_OK
    end

    ### Pull weather data and output it
    ###
    def weather( data, buffer, args )

        # get and validate units
        units = self.units
        units = 'imperial' unless units =~ /(imperial|metric)/

        # get city
        city = args
        city = self.default_city if city.empty?
        city = city.gsub(/ /, '%20')

        doc = JSON.parse(
                xml = open('http://api.openweathermap.org/data/2.5/find?q=%s&units=%s&mode=json&type=acurate' % [ city, units ]).read
        )

        count = doc['count']
        if count.nil?
            self.print buffer, "Invalid City, please see /help %s" % [ $PROGRAM_NAME ]
            return WEECHAT_RC_OK
        end

        unless count > 0
            self.print buffer, "No Weather Data for #{city}"
            return WEECHAT_RC_OK
        end

        self.print buffer, "Found #{count} cities matching '#{args}'" if count > 1

        # Set our default city, if not already set
        Weechat.config_set_plugin( 'default_city', args ) if Weechat.config_get_plugin( 'default_city' ).empty?

        doc['list'].each do |item|
            self.print buffer, "%s%s: %2.1f degrees; relative humidity: %d%%; currently: %s" % [
                    item['name'],
                    count > 1 ? ' / ' + item['sys']['country'] : '',
                    item['main']['temp'].to_f,
                    item['main']['humidity'].to_i,
                    item['weather'][0]['description']
            ]
        end

        return WEECHAT_RC_OK
    end


    ########################################################################
    ### I N S T A N C E   M E T H O D S
    ########################################################################

    #########
    protected
    #########

    ### Quick wrapper for sending info messages to the weechat main buffer.
    ###
    def print_info( msg )
        Weechat.print '', "%s%s\t%s" % [ Weechat.color('yellow'), $PROGRAM_NAME, msg ]
    end

    def print( buffer, msg )
        Weechat.print buffer, "%s***\t%s%s" % [ Weechat.color('yellow'), Weechat.color('white'), msg ]
    end
end


### Weechat entry point.
###
def weechat_init
    require 'rubygems'
    require 'open-uri'
    require 'json'

    Weechat::register *OpenWeather::SIGNATURE
    $obj = OpenWeather.new

    Weechat.hook_config( 'plugins.var.ruby.openweather.*', 'config_changed_cb', '' )
    Weechat.hook_command *OpenWeather::COMMAND

    return Weechat::WEECHAT_RC_OK

rescue LoadError => err
    Weechat.print '', "%s: %s, %s\n$LOAD_PATH: %p" % [
            $PROGRAM_NAME,
            err.class.name,
            err.message,
            $LOAD_PATH
    ]
    Weechat.print '', $PROGRAM_NAME + ': Unable to initialize due to missing dependencies.'
    return Weechat::WEECHAT_RC_ERROR
end

### Hook for manually unloading this script.
###
def weechat_unload
    Weechat.unhook_all()
    return Weechat::WEECHAT_RC_OK
end


### Allow Weechat namespace callbacks to forward to our object.
###
require 'forwardable'
extend Forwardable
def_delegators :$obj, :config_changed_cb, :weather


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

