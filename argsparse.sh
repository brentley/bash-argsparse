#!/bin/bash
# -*- encoding: utf-8 -*-
#
# Bash Argsparse Library
# Author: Damien Nadé <bash-argsparse@livna.org>
# URL: https://github.com/Anvil/bash-argsparse
#
#########
# License:
#
#             DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
# Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
#
# Everyone is permitted to copy and distribute verbatim or modified
# copies of this license document, and changing it is allowed as long
# as the name is changed.
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.
#
#########
#
# Description and purpose:
#
# To replace the option-parsing and usage-describing functions
# commonly rewritten in all scripts.
#
# This library is implemented for bash version 4. Prior versions of
# bash will fail at interpreting that code.
#
##
#
# Use the argsparse_use_option function to declare your options with
# their single letter counterparts, along with the description.
#
# The argsparse_use_option syntax is:
#
#     argsparse_use_option "optstring" "option description string" \
#		[ "property" ... ] [ "optional default value" ]
#
# An "optstring" is of the form "som=estring:". This would declare a
# long option named somestring. The ending ':' is optional and, if
# present, means the long option expects a value on the command
# line. The '=' char is also optional and means the immediatly
# following letter is the short single-letter equivalent option of
# --something.
#
# The 'something' string must only contains ASCII
# letters/numbers/dash/underscore characters.
#
# What is referred later as "option" or "option name" (or even "long
# option name") is the optstring without the ':' and '=' characters.
#
# TODO: There are some currently unhandled conflicts between foo-bar
# and foo_bar options.
#
##
#
# Options may have properties.
#
# Properties are set either at option declarations through the
# argsparse_use_option function, or using the
# argsparse_set_option_property function
#
# The currently supported properties are:
#
# * "hidden"
# 	An hidden option will not be shown in usage.
#
# * "mandatory"
#	An option marked as mandatory is required on the command line. If
#	a mandatory option is omited by the user, usage will be triggered
#	by argsparse_parse_options.
#
# * "value"
#   On the command line, the option will require a value.
#	Same effect if you end your optstring with a ':' char.
#
# * "default:<defaultvalue>"
#	The default value for the option.
#
# * "short:<char>"
#   The short single-letter equivalent of the option.
#
# * "type:<typename>" Give a type to the option value. User input
#	value will be checked against built-in type verifications _or_ the
#	check_type_<typename> function. You cannot override a built-in
#	type. Built-in types are:
#
#   file directory pipe terminal socket link char unsignedint uint
#   integer int hexa ipv4 ipv6 ip hostname host portnumber port
#   username group
#
# * "exclude:<option> <option>"
#   The exclude property value is a space-separated list of other
#   options. User wont be able to provided two mutually exclusive
#   options on the command line.
#
#   e.g: if you set exclude property for the --foo option this way:
#   argsparse_set_option_property "exclude:opt1 opt2" foo
#   Then --opt1 and --foo are not allowed on the same command line
#   invokation. And same goes for --opt2 and --foo.
#   This foo exclude property setting wouldnt make --opt1 and --opt2,
#   mutually exclusive though.
#
# * "alias:<option> <option>"
#   This property allows an option to set multiple other without-value
#   options instead. Recursive aliases are permitted but no loop
#   detection is made, so be careful.
#
#   e.g: if you declare an option 'opt' like this:
#   argsparse_use_option opt "my description" "alias:opt1 opt2"
#   Then if the user is doing --opt on the command line, it will be as
#   if he would have done --opt1 --opt2
#
# * cumulative
#   Implies 'value'.
#   Everytime a cumulative option "optionname" is passed on the
#   command line, the value is stored at the end of an array named
#   "cumulated_values_<optionname>".
#
#   e.g: for a script with an opt1 option declared this way:
#   argsparse_use_option opt1 "some description" cumulative
#   and invoked with: --opt1 value1 --opt1 value2
#   after argsparse_parse_options, ${cumulated_values_opt1[0]} will
#   expand to value1, and ${cumulated_values_opt1[1]} will expand to
#   value2.
#
# * cumulativeset
#   Exactly like cumulative, except only uniq values are kept.
#
#   e.g: for a script with an opt1 option declared this way:
#   argsparse_use_option opt1 "some description" cumulativeset
#   and invoked with: --opt1 value1 --opt1 value2 --opt1 value1
#   after argsparse_parse_options, ${cumulated_values_opt1[0]} will
#   expand to value1, and ${cumulated_values_opt1[1]} will expand to
#   value2. There would be no ${cumulated_values_opt1[2]} value.
#
# You can test if an option has a property using the
# argsparse_has_option_property function.
# argsparse_has_option_property <option> <property>
#
##
#
# After the options are declared, invoke the function
# argsparse_parse_options with the all script parameters. This will
# define:
#
# * program_params, an array, containing all non-option parameters.
#
# * program_options, an associative array. For each record of the
#   array:
#   * The key is the long option name.
#   * And about values:
#
#     * If option doesn't expect a value on the command line, the
#       value represents how many times the option has been
#       found on the command line
#
#     * If option does require a value, the array record value is the
#       value of the last occurence of the option found on the command
#       line.
#
#     * If option is cumulative (or cumulativeset), the array record
#       value is the number of values passed by the user.
#
# After argsparse_parse_options invokation, you can check if an option
# have was on the command line (or not) using the
# argsparse_is_option_set function.
#
# e.g:
# argsparse_is_option_set "long-option-name"
#
##
#
# If a 'usage' function is defined, and shall parse_option return with
# non-zero status, 'usage' will be automatically called.
#
# This file automatically defines a default 'usage' function, which
# may be removed or overridden by the program.
#
##
#
# During option parsing, for every option of the form '--optionname'
# expecting a value:
#
# * If there exists an array named 'option_<optionname>_values' and
#   the user-given value doesn't belong to that array, then the
#   argsparse_parse_options function immediately returns with non-zero
#   status, triggering 'usage'.
#
# * If the 'option_<optionname>_values' array does not exist, but if
#   the option has a type property field, then the value format will
#   be checked agaisnt that type.
#
# * If a function named 'check_value_of_longtoption' has been defined,
#   it will be called with the user-given value as its first
#   positionnal parameter. If check_value_of_optionname returns with
#   non-zero status, then parse_option immediately returns with
#   non-zero status, triggering the 'usage' function.
#
# Also, still during option parsing and for *every* option of the form
# '--optionname':
#
# * After value-checking, if a function named 'set_option_optionname'
#   exists, then, instead of directly modifying the 'program_options'
#   associative array, this function is automatically called with
#   'optionname' as its first positionnal parameter, and, if
#   'optionname' expected a value, the value is given as the function
#   second positionnal parameter.
#
##
#
# We're not compatible with older bash versions.
if [[ "$BASH_VERSINFO" -lt 4 ]]
then
	printf >&2 "This requires bash >= 4 to run.\n"
	return 1 2>/dev/null
	exit 1
fi

if ! command -v getopt >/dev/null 2>&1
then
	printf >&2 "Cannot find the getopt command.\n"
	return 1 2>/dev/null
	exit 1
fi

ARGSPARSE_VERSION=1.5

# Enable required features
shopt -s extglob

# This is an associative array. It should contains records of the form
# "something" -> "Some usage description string".
# The "something" string is referred as the "option name" later in
# source code and comments.
declare -A __argsparse_options_descriptions=()

# The program name
__argsparse_pgm=${0##*/}


# The default minimum parameters requirement for command line.
__argsparse_minimum_parameters=0

argsparse_minimum_parameters() {
	# Set the minimum number of non-option parameters expected on the
	# command line. (the __argsparse_minimum_parameters value)
	# @param a positive number.
	[[ $# -eq 1 ]] || return 1
	local min=$1
	[[ "$min" = +([0-9]) ]] || return 1
	__argsparse_minimum_parameters=$min
}

# "Should be enough for everyone". At least as a default.
__argsparse_maximum_parameters=100000

argsparse_maximum_parameters() {
	# Set the maximum number of non-option parameters expected on the
	# command line. (the __argsparse_maximum_parameters value)
	# @param a positive number.
	[[ $# -eq 1 ]] || return 1
	local max=$1
	[[ "$max" = +([0-9]) ]] || return 1
	__argsparse_maximum_parameters=$max
}


# 2 generic functions
__argsparse_index_of() {
	# Checks if a key belongs to an array.
	# @param: a key
	# @params: array keys
	# @return 0 if first parameter is amongst other parameters and
	# prints the found index. Else prints nothing and returns 1.
	[[ $# -ge 2 ]] || return 1
	local key=$1 ; shift
	local index=0
	local elem
	for elem in "$@"
	do
		if [[ "$key" = "$elem" ]]
		then
			printf %s "$index"
			return 0
		fi
		: $((index++))
	done
	return 1
}

__argsparse_join_array() {
	# Like the 'join' string method in python, join multiple
	# strings by a char.
	# @param a single char
	# @param multiple string.
	[[ $# -ge 1 && $1 = ? ]] || return 1
	local IFS="$1$IFS"
	shift
	printf %s "$*"
}

argsparse_option_to_identifier() {
	# Transforms and prints an option name into a string which can be
	# part of a function or variable name.
	# @param an option name.
	# @return 0
	[[ $# -eq 1 ]] || return 1
	local option=$1
	printf %s "${option//-/_}"
}

# Following functions define the default option-setting hook and its
# with/without value counter-parts. They can be referered in external
# source code, though they should only be in user-defined
# option-setting hooks.

# All user-defined option-setting hook should be defined like
# argsparse_set_option

argsparse_set_option_without_value() {
	# The default action to take for options without values.
	# @param a long option name
	[[ $# -eq 1 ]] || return 1
	local option=$1
	: $((program_options["$option"]++))
}

argsparse_set_option_with_value() {
	# The default action to take for options with values.
	# @param a long option name
	# @param the value put on command line for given option.
	[[ $# -eq 2 ]] || return 1
	local option=$1
	local value=$2
	program_options["$option"]=$value
}

__argsparse_get_cumulative_array_name() {
	# Prints the name of the array used to stored cumulated values of
	# an option.
	# @param an option name
	[[ $# -eq 1 ]] || return 1
	local option=$1
	local ident=$(argsparse_option_to_identifier "$option")
	printf "cumulated_values_%s" "$ident"
}

argsparse_set_cumulative_option() {
	# The default action to take for cumulative options.
	# @param a long option name
	# @param the value put on command line for given option.
	[[ $# -eq 2 ]] || return 1
	local option=$1
	local value=$2
	local array="$(__argsparse_get_cumulative_array_name "$option")"
	local size temp="$array[@]"
	local -a copy
	copy=( "${!temp}" )
	size=${#copy[@]}
	printf -v "$array[$size]" %s "$value"
	argsparse_set_option_without_value "$option"
}

argsparse_set_cumulativeset_option() {
	# The default action to take for cumulativeset options.
	# @param a long option name
	# @param the value put on command line for given option.
	[[ $# -eq 2 ]] || return 1
	local option=$1
	local value=$2
	local array="$(__argsparse_get_cumulative_array_name "$option")[@]"
	if ! __argsparse_index_of "$value" "${!array}" >/dev/null
	then
		# The value is not already in the array, so add it.
		argsparse_set_cumulative_option "$option" "$value"
	fi
}

argsparse_set_alias() {
	# This option will set all options aliased by another.
	[[ $# -eq 1 ]] || return 1
	local option=$1
	local aliases
	if ! aliases="$(argsparse_has_option_property "$option" alias)"
	then
		return 1
	fi
	while [[ "$aliases" =~ ^\ *([^\ ]+)(\ (.+))?\ *$ ]]
	do
		# At this point, BASH_REMATCH[1] is the first alias, and
		# BASH_REMATCH[3] is the maybe-empty list of other aliases.
		# __argsparse_set_option will alter BASH_REMATCH, so modify
		# aliases first.
		aliases=${BASH_REMATCH[3]}
		__argsparse_set_option "${BASH_REMATCH[1]}"
	done
}

argsparse_set_option() {
	# This function is the default option-setting hook.
	# @param an option name.
	# @param an optional value.
	[[ $# -eq 2 || $# -eq 1 ]] || return 1
	local option=$1
	if [[ $# -eq 2 ]]
	then
		local value=$2
	fi

	local -A setters=(
		[cumulative]=argsparse_set_cumulative_option
		[cumulativeset]=argsparse_set_cumulativeset_option
		[value]=argsparse_set_option_with_value
	)

	if ! argsparse_set_alias "$option"
	then
		# We dont use ${!setters[@]} here, because order matters.
		for property in cumulative cumulativeset value
		do
			if argsparse_has_option_property "$option" "$property"
			then
				"${setters[$property]}" "$option" "$value"
				return
			fi
		done
		argsparse_set_option_without_value "$option"
	fi
}


# The usage-related functions.

argsparse_usage_short() {
	# This function generates and prints the short description of the
	# program usage.
	local option values current_line current_option bigger_line
	local max_length=78
	current_line=$__argsparse_pgm
	for option in "${!__argsparse_options_descriptions[@]}"
	do
		if argsparse_has_option_property "$option" hidden
		then
			continue
		fi
		current_option="--$option"
		if argsparse_has_option_property "$option" value
		then
			if values=$(__argsparse_values_array_identifier "$option")
			then
				current_option="$current_option <$(
					__argsparse_join_array '|' "${!values}")>"
			else
				current_option="$current_option ${option^^}"
			fi
		fi
		if ! argsparse_has_option_property "$option" mandatory
		then
			current_option="[ $current_option ]"
		fi
		bigger_line="$current_line $current_option"
		if [[ "${#bigger_line}" -gt "$max_length" ]]
		then
			printf -- '%s \\\n' "$current_line"
			printf -v current_line "\t%s" "$current_option"
		else
			current_line=$bigger_line
		fi
	done
	printf -- "%s\n" "$current_line"
}

argsparse_usage_long() {
	# This function generates and prints the long description of the
	# program usage.
	local long short sep format array aliases
	local q=\' bol='\t\t  '
	local -A long_to_short=()
	local -a values
	for short in "${!__argsparse_short_options[@]}"
	do
		long=${__argsparse_short_options["$short"]}
		long_to_short["$long"]=$short
	done
	for long in "${!__argsparse_options_descriptions[@]}"
	do
		if argsparse_has_option_property "$long" hidden
		then
			continue
		fi
		# Pretty printer issue here. If the long option length is
		# greater than 8, we just use next line to print the option
		# description.
		if [[ "${#long}" -le 9 ]]
		then
			sep=' '
		else
			sep="\n$bol"
		fi
		# Define format according to the presence of the short option.
		short=${long_to_short["$long"]}
		if [[ -n "$short" ]]
		then
			format=" -%s | %- 11s$sep%s\n"
		else
			format=" %s     %- 11s$sep%s\n"
		fi
		printf -- "$format" "$short" "--$long" \
			"${__argsparse_options_descriptions["$long"]}"
		if argsparse_has_option_property "$long" cumulative || \
			argsparse_has_option_property "$long" cumulativeset
		then
			printf "${bol}Can be repeated.\n"
		fi
		if argsparse_has_option_property "$long" value && \
			array=$(__argsparse_values_array_identifier "$long")
		then
			values=( "${!array}" )
			values=( "${values[@]/%/$q}" )
			values=( "${values[@]/#/$q}" )
			printf "${bol}Acceptable values: %s\n" \
				"$(__argsparse_join_array " " "${values[@]}")"
		fi
		if aliases=$(argsparse_has_option_property "$long" alias)
		then
			read -a values <<<"$aliases"
			values=( "${values[@]/#/--}" )
			printf "${bol}Same as: %s\n" "${values[*]}"
		fi
	done
}

argsparse_usage() {
	# This is a generic help message generated by the options and
	# their descriptions.
	# There's still a lot of room for improvement here.
	argsparse_usage_short
	printf "\n"
	# This will print option descriptions.
	argsparse_usage_long
	[[ -z "$argsparse_usage_description" ]] || \
		printf "\n%s\n" "$argsparse_usage_description"
}

usage() {
	# The default usage function. It can easily be overwritten if it
	# doesnt suits your needs.
	argsparse_usage
	exit 1
}

set_option_help() {
	# This is the default hook for the --help option.
	usage
}

__argsparse_values_array_identifier() {
	# Prints the name of the array which will contain all the values
	# of an option with the cumulative or cumulativeset property.
	# @param an option name
	local option=$1
	local array="option_${option}_values"
	__argsparse_is_array_declared "$array" || return 1
	printf %s "$array[@]"
}

#

__argsparse_is_array_declared() {
	# @param an array name.
	# @return 0 if an array has been already declared by the name of
	# the parameter.
	[[ $# -eq 1 ]] || return 1
	local array_name=$1
	[[ "$(declare -p "$array_name" 2>/dev/null)" = \
		"declare -"[aA]" $array_name='("* ]]
}

__argsparse_check_missing_options() {
	# @return 0 if all mandatory options have a value in
	# program_options associative array.
	local option count=0
	for option in "${!__argsparse_options_descriptions[@]}"
	do
		argsparse_has_option_property "$option" mandatory || continue
		# If option has been given, just iterate.
		argsparse_is_option_set "$option" && continue
		printf >&2 "%s: --%s: option is mandatory.\n" \
			"$__argsparse_pgm" "$option"
		: $((count++))
	done
	[[ "$count" -eq 0 ]]
}

argsparse_check_option_type() {
	# Check if a value matches a given type.
	# @param a type. A type name is case insensitive.
	# @param a value to check
	# @returns 0 if the value matches the given type format.
	[[ $# -eq 2 ]] || return 1
	local option_type=${1,,}
	local value=$2
	local t
	case "$option_type" in
		file|directory|pipe|terminal)
			# [[ wont accept the -$var as an operator.
			[ -"${option_type:0:1}" "$value" ]
			;;
		socket|link)
			t=${option_type:0:1}
			[ -"${t^^}" "$value" ]
			;;
		char)
			[[ "$value" = ? ]]
			;;
		unsignedint|uint)
			[[ "$value" = +([0-9]) ]]
			;;
		integer|int)
			[[ "$value" = ?(-)+([0-9]) ]]
			;;
		hexa)
			[[ "$value" = ?(0x)+([a-fA-F0-9]) ]]
			;;
		ipv4)
			# Regular expression for ipv4 and ipv6 have been found on
			# http://www.d-sites.com/2008/10/09/regex-ipv4-et-ipv6/
			[[ "$value" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?).(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]
			;;
		ipv6)
			[[ "$value" =~ ^((([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){6}:[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){5}:([0-9A-Fa-f]{1,4}:)?[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){4}:([0-9A-Fa-f]{1,4}:){0,2}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){3}:([0-9A-Fa-f]{1,4}:){0,3}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){2}:([0-9A-Fa-f]{1,4}:){0,4}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){6}((b((25[0-5])|(1d{2})|(2[0-4]d)|(d{1,2}))b).){3}(b((25[0-5])|(1d{2})|(2[0-4]d)|(d{1,2}))b))|(([0-9A-Fa-f]{1,4}:){0,5}:((b((25[0-5])|(1d{2})|(2[0-4]d)|(d{1,2}))b).){3}(b((25[0-5])|(1d{2})|(2[0-4]d)|(d{1,2}))b))|(::([0-9A-Fa-f]{1,4}:){0,5}((b((25[0-5])|(1d{2})|(2[0-4]d)|(d{1,2}))b).){3}(b((25[0-5])|(1d{2})|(2[0-4]d)|(d{1,2}))b))|([0-9A-Fa-f]{1,4}::([0-9A-Fa-f]{1,4}:){0,5}[0-9A-Fa-f]{1,4})|(::([0-9A-Fa-f]{1,4}:){0,6}[0-9A-Fa-f]{1,4})|(([0-9A-Fa-f]{1,4}:){1,7}:))$ ]]
			;;
		ip)
			# Generic IP address.
			argsparse_check_option_type ipv4 "$value" || \
				argsparse_check_option_type ipv6 "$value"
			;;
		hostname)
			# check if value resolv as an IPv4 or IPv6 address.
			host -t a "$value" >/dev/null 2>&1 || \
				host -t aaaa "$value" >/dev/null 2>&1
			;;
		host)
			# An hostname or an IP address.
			argsparse_check_option_type hostname "$value" || \
				argsparse_check_option_type ipv4 "$value" || \
				argsparse_check_option_type ipv6 "$value"
			;;
		portnumber)
			argsparse_check_option_type uint "$value" && \
				[[ "$value" -gt 0 && "$value" -le 65536 ]]
			;;
		port)
			# Port number or service.
			argsparse_check_option_type portnumber "$value" || \
				getent services "$value" >/dev/null 2>&1
			;;
		username)
			getent passwd "$value" >/dev/null 2>&1
			;;
		group)
			getent group "$value" >/dev/null 2>&1
			;;
		*)
			# Invoke user-defined type-checking function if available.
			if ! declare -f "check_option_type_$option_type" >/dev/null
			then
				printf >&2 \
					"%s: %s: type has no validation function. This is a bug.\n" \
					"$__argsparse_pgm" "$option_type"
				return 2
			fi
			"check_option_type_$option_type" "$value"
			;;
	esac
}

__argsparse_parse_options_valuecheck() {
	# Check a value.
	# If an enumeration has been defined for the option, check against
	# that. If there's no enumeration, but option has a type property,
	# then check against the type.
	# In the end, check against check_value_of_<option> function, if
	# it's been defined.
	# @param an option name
	# @param a value
	# @return 0 if value is correct for given option.
	[[ $# -eq 2 ]] || return 1
	local option=$1
	local value=$2
	local identifier possible_values option_type
	identifier="$(argsparse_option_to_identifier "$option")"
	if possible_values=$(__argsparse_values_array_identifier "$identifier")
	then
		__argsparse_index_of "$value" "${!possible_values}" >/dev/null || \
			return 1
	elif option_type=$(argsparse_has_option_property "$option" type)
	then
		argsparse_check_option_type "$option_type" "$value" || return 1
	fi
	if declare -f "check_value_of_$identifier" >/dev/null 2>&1
	then
		"check_value_of_$identifier" "$value" || return 1
	fi
	return 0
}

# Default behaviour is not to accept empty command lines.
__argsparse_allow_no_argument=no

argsparse_allow_no_argument() {
	# Change argsparse behaviour for empty command lines. Default says
	# no argument triggers usage.
	# @param if (case-insensitive) "yes", "true" or "1", the value is
	# considered as affirmative. Anything else is a negative value.
	# @return 0 unless there's more than one parameter (or none).
	[[ $# -eq 1 ]] || return 1
	local param=$1
	case "${param,,}" in
		yes|true|1)
			__argsparse_allow_no_argument=yes
			;;
		*)
			__argsparse_allow_no_argument=no
			;;
	esac
}

argsparse_parse_options() {
	# @params should be the program arguments.
	# This function will make option parsing happen, and if an error
	# is detected, the usage function will be invoked, if it has been
	# defined. If it's not defined, the function will return 1.
	# Parse options, and return if everything went fine.
	__argsparse_parse_options_no_usage "$@" && return
	# Something went wrong, invoke usage function, if defined.
	declare -f usage >/dev/null 2>&1 && usage
	return 1
}


__argsparse_parse_options_prepare_exclude() {
	# Check for all "exclude" properties, and fill "exclusions"
	# associative array, which should have been declared in
	# __argsparse_parse_options_no_usage.
	local option exclude excludestring
	local -a excludes
	for option in "${!__argsparse_options_descriptions[@]}"
	do
		excludestring=$(argsparse_has_option_property "$option" exclude) || \
			continue
		exclusions["$option"]+="${exclusions["$option"]:+ }$excludestring"
		# Re-split the string. (without involving anything else)
		read -a excludes <<<"$excludestring"
		for exclude in "${excludes[@]}"
		do
			exclusions["$exclude"]+="${exclusions["$exclude"]:+ }$option"
		done
	done
}

__argsparse_parse_options_check_exclusions() {
	# Check if two options presents on the command line are mutually
	# exclusive. Prints the "other" option if it's the case.
	# @param an option
	# @return 0 if the given option has actually excluded by annother
	# already-given option.
	[[ $# -eq 1 ]] || return 1
	local new_option=$1
	local option

	for option in "${!program_options[@]}"
	do
	if [[ "${exclusions["$option"]}" =~ ^(.* )?"$new_option"( .*)?$ ]]
	then
		printf %s "$option"
		return 0
	fi
	done
	return 1
}

__argsparse_set_option() {
	# @param an option
	[[ $# -eq 1 || $# -eq 2 ]] || return 1
	local option=$1
	local set_hook identifier
	[[ $# -ne 2 ]] || local value=$2
	# The "identifier string" matching next_param, suitable for
	# variable or function names.
	identifier="$(argsparse_option_to_identifier "$option")"
	# If user has defined a specific setting hook for given the
	# option, then use it, else use default standard
	# option-setting function.
	if declare -f "set_option_$identifier" >/dev/null 2>&1
	then
		set_hook="set_option_$identifier"
	else
		set_hook=argsparse_set_option
	fi
	# Invoke setting hook, and if it returns returns some non-zero
	# status, send the user back to usage, if declared, and return
	# with error.
	# The specific $value substitution, here, is to distinguish an
	# empty value from a no-value.
	"$set_hook" "$option" ${value+"$value"}
}

__argsparse_parse_options_no_usage() {
	# This function re-set program_params array values. This function
	# will also modify the program_options associative array.
	# If any error happens, this function will return 1.

	# Be careful, the function is (too) big.

	local long short getopt_temp next_param set_hook option_type
	local next_param_identifier exclude value
	local -a longs_array
	local -A exclusions
	# The getopt parameters.
	local longs shorts option

	# No argument sends back to usage, if defined.
	if [[ $# -eq 0 && "$__argsparse_allow_no_argument" != yes ]]
	then
		return 1
	fi

	# 1. Analyze declared options to create getopt valid arguments.
	for long in "${!__argsparse_options_descriptions[@]}"
	do
		if argsparse_has_option_property "$long" value
		then
			longs_array+=( "$long:" )
		else
			longs_array+=( "$long" )
		fi
	done

	# 2. Create the long options string.
	longs="$(__argsparse_join_array , "${longs_array[@]}")"

	# 3. Create the short option string.
	for short in "${!__argsparse_short_options[@]}"
	do
		if argsparse_has_option_property \
			"${__argsparse_short_options[$short]}" value
		then
			shorts+="$short:"
		else
			shorts+=$short
		fi
	done

	# 4. Invoke getopt and replace arguments.
	if ! getopt_temp=$(getopt -s bash -n "$__argsparse_pgm" \
		--longoptions="$longs" "$shorts" "$@")
	then
		# Syntax error on the command implies returning with error.
		return 1
	fi
	eval set -- "$getopt_temp"

	# 5. Prepare exclusions stuff.
	__argsparse_parse_options_prepare_exclude

	# 6. Arguments parsing is really made here.
	while [[ $# -ge 1 ]]
	do
		next_param=$1
		shift
		# The regular exit case.
		if [[ "$next_param" = -- ]]
		then
			# Check how many parameters we have and if it's at least
			# what we expects.
			if [[ $# -lt "$__argsparse_minimum_parameters" ]]
			then
				printf >&2 \
					"%s: not enough parameters (at least %d expected, %d provided)\n" \
					"$__argsparse_pgm" "$__argsparse_minimum_parameters" $#
				return 1
			elif [[ $# -gt "$__argsparse_maximum_parameters" ]]
			then
				printf >&2 \
					"%s: too many parameters (maximum allowed is %d, %d provided)\n" \
					"$__argsparse_pgm" "$__argsparse_maximum_parameters" $#
				return 1
			fi
			# Save program parameters in array
			program_params=( "$@" )
			# If some mandatory option have been omited by the user, then
			# print some error, and invoke usage.
			__argsparse_check_missing_options
			return
		fi
		# If a short option was given, then we first convert it to its
		# matching long name.
		if [[ "$next_param" = -[!-] ]]
		then
			next_param=${next_param#-}
			if [[ -z "${__argsparse_short_options[$next_param]}" ]]
			then
				# Short option without equivalent long. According to
				# current implementation, this should be considered as
				# a bug.
				printf >&2 \
					"%s: -%s: option doesnt have any matching long option." \
					"$__argsparse_pgm" "$next_param"
				return 1
			fi
			next_param=${__argsparse_short_options[$next_param]}
		else
			# Wasnt a short option. Just strip the leading dash.
			next_param=${next_param#--}
		fi
		if exclude=$(__argsparse_parse_options_check_exclusions "$next_param")
		then
			printf >&2 \
				"%s: %s: option excluded by other option (%s).\n" \
				"$__argsparse_pgm" "$next_param" "$exclude"
			return 1
		fi
		# Set option value, if there should be one.
		if argsparse_has_option_property "$next_param" value
		then
			value=$1
			shift
			if ! __argsparse_parse_options_valuecheck "$next_param" "$value"
			then
				printf >&2 "%s: %s: Invalid value for option %s.\n" \
					"$__argsparse_pgm" "$value" "$next_param"
				return 1
			fi
		fi
		# Invoke setting hook, and if it returns returns some non-zero
		# status, send the user back to usage, if declared, and return
		# with error.
		# The specific $value substitution, here, is to distinguish an
		# empty value from a no-value.
		if ! __argsparse_set_option "$next_param" ${value+"$value"}
		then
			printf >&2 "%s: %s: Invalid value for %s option.\n" \
				"$__argsparse_pgm" "$value" "$next_param"
			return 1
		fi
		unset value
	done
	return 0
}

# program_options is an associative array containing (if no hook is set)
# 'longoption' -> value, if longoption accepts a value
# or
# 'longoption' -> how many times the option has been detected on the
# 			      command line.
declare -A program_options=()

# program_params is a standard array which will contains all
# non-option parameters. (Typically, everything found after the '--')
declare -a program_params=()

argsparse_reset() {
	# Reset important global arrays.
	program_options=()
	program_params=()
	__argsparse_short_options=()
}


# Option properties
declare -A __argsparse_option_properties=()

argsparse_set_option_property() {
	# Enable a property to a list of options.
	# @param a property name.
	# @params option names.
	# @return non-zero if property is not supported.
	[[ $# -ge 2 ]] || return 1
	local property=$1
	shift
	local option p
	for option in "$@"
	do
		case "$property" in
			cumulative|cumulativeset)
				argsparse_set_option_property value "$option"
				;;&
			type:*|exclude:*|alias:*)
				if [[ "$property" =~ ^.*:(.+)$ ]]
				then
					# If property has a value, check its format, we
					# dont want any funny chars.
					if [[ "${BASH_REMATCH[1]}" = *[*?!,]* ]]
					then
						printf >&2 "%s: %s: invalid property value.\n" \
							"$__argsparse_pgm" "${BASH_REMATCH[1]}"
						return 1
					fi
				fi
				;&
			mandatory|hidden|value|cumulative|cumulativeset)
				# We use the comma as the property character separator
				# in the __argsparse_option_properties array.
				p=${__argsparse_option_properties["$option"]}
				__argsparse_option_properties["$option"]="${p:+$p,}$property"
				;;
			short:?)
				short=${property#short:}
				if [[ -n "${__argsparse_short_options[$short]}" ]]
				then
					printf >&2 \
						"%s: %s: short option for %s conflicts with already-configured short option for %s.\n" \
						"$__argsparse_pgm" "$short" "$option" \
						"${__argsparse_short_options[$short]}"
					return 1
				fi
				__argsparse_short_options["$short"]=$option
				;;
			default:*)
				# The default value
				program_options["$option"]=${property#default:}
				;;
			*)
				return 1
				;;
		esac
	done
}

argsparse_has_option_property() {
	# Return 0 if property has been set for given option, and print
	# the property value, if available.
	# @param an option name.
	# @param a property name.
	# @return 0 if option has given property.
	[[ $# -eq 2 ]] || return 1
	local option=$1
	local property=$2
	local p=${__argsparse_option_properties["$option"]}
	if ! [[ "$p" =~ (^|.+,)"$property"(:([^,]+))?($|,.+) ]]
	then
		return 1
	fi
	printf %s "${BASH_REMATCH[3]}"
}

# Association short option -> long option.
declare -A __argsparse_short_options=()

_argsparse_optstring_has_short() {
	# Prints the short option string suitable for getopt command line.
	# @param an optstring
	# @return non-zero if given optstring doesnt have any short option
	# equivalent.
	[[ $# -eq 1 ]] || return 1
	local optstring=$1
	if [[ "$optstring" =~ .*=(.).* ]]
	then
		printf %c "${BASH_REMATCH[1]}"
		return 0
	fi
	return 1
}

argsparse_use_option() {
	# Define a new option.
	# @param an optstring.
	# @param the option description, for the usage function.
	# @params an non-ordered list of keywords. Recognized keywords are:
	#   * mandatory: missing option will trigger usage. If a default
	#     value is given, the option is considered as if provided on
	#     the command line.
	#   * hidden: option wont show in default usage function.
	#   * value: option expects a following value.
	#   * short:c: option has a single-lettered (c) equivalent.
	#   * exclude:"option1 [ option2 ... ]" option is not
	#   compatible with other options option1, option2...
	#   * cumulative
	#   * cumulativeset
	#   * type:sometype
	#   * The *last* non-keyword parameter will be considered as the
	#     default value for the option. All other parameters and
	#     values will be ignored. - might be broken / obsolete and broken
	# @return 0 if no error is encountered.
	[[ $# -ge 2 ]] || return 1
	local optstring=$1
	local description=$2
	shift 2
	local long short
	# configure short option.
	if short=$(_argsparse_optstring_has_short "$optstring")
	then
		set -- "short:$short" "$@"
		optstring=${optstring/=/}
	fi
	# --$optstring expect an argument.
	if [[ "$optstring" = *: ]]
	then
		set -- value "$@"
		long=${optstring%:}
	else
		long=$optstring
	fi

	if [[ "$long" = *[!-0-9a-zA-Z_]* ]]
	then
		printf >&2 "%s: %s: bad option name.\n" "$__argsparse_pgm" "$long"
		return 1
	fi

	__argsparse_options_descriptions["$long"]=$description

	# Any other parameter to this function should be a property.
	while [[ $# -ne 0 ]]
	do
		if ! argsparse_set_option_property "$1" "$long"
		then
			printf >&2 '%s: %s: unknown property.\n' "$__argsparse_pgm" "$1"
			return 1
		fi
		shift
	done
}

argsparse_is_option_set() {
	# @param an option name
	# @return 0 if given option has been set on the command line.
	[[ $# -eq 1 ]] || return 1
	local option=$1
	[[ -n "${program_options[$option]+yes}" ]]
}

# We do define a default --help option.
argsparse_use_option "=help" "Show this help message"

__max_length() {
	# Prints the length of the longest argument _or_ 50.
	# @params a list of strings
	# @return 0
	local max=50
	shift
	local max_length=0 str
	for str in "$@"
	do
		max_length=$((max_length>${#str}?max_length:${#str}))
	done
	printf %d "$((max_length>max?max:max_length))"
}

argsparse_report() {
	# Prints a basic report of all passed options
	# Kinda useful for a --debug, or a --verbose option.
	# Parameters are ignored. Should return 0.
	local option array_name value
	local length=$(__max_length "${!__argsparse_options_descriptions[@]}")
	local -a array
	for option in "${!__argsparse_options_descriptions[@]}"
	do
		argsparse_has_option_property "$option" hidden && continue
		printf "%- ${length}s\t: " "$option"
		if argsparse_is_option_set "$option"
		then
			printf "yes (%s" "${program_options[$option]}"
			if argsparse_has_option_property "$option" cumulative
			then
				array_name="$(__argsparse_get_cumulative_array_name "$option")[@]"
				array=( "${!array_name}" )
				printf ' time(s):'
				for value in "${array[@]}"
				do
					printf ' %q' "$value"
				done
			fi
			printf ')\n'
		else
			printf '%s\n' no
		fi
	done
}

return 0 >/dev/null 2>&1 ||:

printf "The %s file is not a standalone program. It's a shell library.\n" \
	"$__argsparse_pgm"
printf "%s\n" \
	"To use it, you have to load it in your own bash" \
	"shell scripts using the following line:"
printf "\n. %q\n\n" "$0"
