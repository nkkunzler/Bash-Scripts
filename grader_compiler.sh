#! /bin/bash

export LC_ALL="en_US.UTF-8"

# ==================================================================
# ============ Should only edit the things between here ============
# ==================================================================

TEST_FILE_EXT_IN="cmm" 
TEST_FILE_EXT_OUT="out"
TEST_FILE_EXT_ERR="err"

TESTCASES_PATH="./testcases/" # SHOULD NOT CHANGE UNLESS YOU NOW WHAT YOU ARE DOING

# ==================================================================
# ==================================================================
# ==================================================================

rc=0 # Return Code, 0 for no failed testcases / 1 for 1+ failed testcases
attempts=0
pass=0

RED='\033[0;31m'
BRN='\033[0;33m'
GRN='\033[0;32m'
NC='\033[0m\n'
NCN='\033[0m'

#######################################
# Prints a message indicating a fatal error and exists with
# an error code of 1.


# Arguments:
#	msg ($1): The message describing what caused a "fatal"
#				error to occur.
# Post-Cond: The script exits with a value of 1
#######################################
function throw_fatal_err() {
	printf "\n${RED}********** FATAL ERROR ***********\n"
	printf "\n$1\n" # The message parameter
	printf "\n**********************************${NC}\n"
	exit 1
}

#######################################
# Executes make on the Makefile within the current
# working directory.
#
# Note: -Werror and -Wall should be included with gcc or else an
#		error is thrown and the script will terminate
#
# Arguments:
#	make_target: String indicating which target make will execute
#	make_clean: String indicating which clean make will execute
# Returns: 
#	If make cannot find the target or clean values, then the proper
#	message indicating such error will print and the program with exit
#	with error code 1.
#	The same thing happens if there were any errors or warnings that
# 	occured when executing the make target.
#######################################
function run_make() {
	make_target=$1 # Used to generate the executable
	make_clean=$2 # Used to clean the result of running make

	# Checking that the make target is in the Makefile
	if [[ $(grep "$make_target" "./Makefile") == "" ]]; then
		throw_fatal_err "Makefile Does Not Contain The Target '$make_target'"
	fi

	# Checking that the make clean is in the Makefile
	if [[ $(grep "$make_clean" "./Makefile") == "" ]]; then
		throw_fatal_err "Makefile Does Not Contain Clean '$make_clean'"
	fi

	for src_file in $(ls .*.c 2>/dev/null); do touch ${src_file}; done

	# Making sure that make did not throw any errors
	(cd . && make "$make_target") >/dev/null 2>/dev/null
	if [[ "$?" -ne 0 ]]; then
		throw_fatal_err "Program Contains Errors / Warnings"
	fi
}

#######################################
# Prints a message indicating that at least 
# one testcasese within the directory failed
#
# Arguments:
#	The name of the directory 
#######################################
function failed_dir_testcases() {
	printf "\n${RED}*****************************************************\n"
	printf "* TESTCASES IN DIRECTORY ${NCN}'$1' ${RED}FAILED\n"
	printf "*****************************************************${NC}"
}

#######################################
# Prints a message indicating that all testcases
# within the directory passed
#
# Arguments:
#	The name of the directory 
#######################################
function passed_dir_testcases() {
	printf "\n${GRN}****************************************************\n"
	printf "* ALL TESTCASES IN DIRECTORY ${NCN}'$1' ${GRN}PASSED\n"
	printf "****************************************************${NC}"
}

#######################################
# Runs all the testcases within a specified directory
#
# Global Vars:
#	pass: The number of testcases passing 
# Arguments:
#	dir_path: 	String indicating the path to the directory 
#				containing the testcases
#	executable:	String indicating which clean make will execute
#	print:		String boolean indicating whether to print the 
#				pass/fail status of each testcase. 
# Post-Cond:	If print is "true", than all testcase status within
#				the specified directory is display; otherwise, an
#				overview report of pass/fail is displayed.
#				All files created by executing 'make' are removed.
# Returns: None
#######################################
function run_dir_testcases() {
	dir_path=$1
	driver=$2
	cmdline_args=$3
	print=$4 # "true" / "false"
	err_code=0 # Used to indicate a pass/fail of the whole directory

	printf "\n${BRN}----- Running Testcases In Directory '$(basename $dir_path)' -----${NC}"

	for testcase in $(ls ${dir_path}/*.${TEST_FILE_EXT_IN} 2>/dev/null) # Getting each testcase
	do
		run_testcase "$testcase" "$driver" "$cmdline_args" "$print"
        if [ $? -ne 0 ]; then
            err_code=1
        else
            pass=$((pass+1))
        fi
	done

	# If indicated not to print out the testcases, give a final report
	# indicating if all testcases in the directory passed or failed
	if [ $err_code -eq 0 ]; then 
		passed_dir_testcases $(basename $dir_path)
	else
		failed_dir_testcases $(basename $dir_path)
	fi
} 

#######################################
# Determines whether two error messages are equal
# 
#
#######################################
function equal_error_line() {
    expected_output=$1 	# Expected error output file
    actual_output=$2 	# Actual error output file

	# It is necessary for the expected output to contain 'error'
	if [ "$(grep -o "[Ee][Rr][Rr][Oo][Rr]" $expected_output)" = "" ]; then
		throw_fatal_err "Expected Error Output Is Missing 'error' Sequence"
	fi

	# It is necessary for the expected output to contain 'line xxx'
	expected_line_num="$(grep -o "[Ll][Ii][Nn][Ee] [0-9]*" $expected_output | cut -d" " -f 2)"
	if [ "$expected_line_num" = "" ]; then
		throw_fatal_err "Expected Error Output Is Missing 'line xxx' Sequence"
	fi

	# Checking if the expected and actual line numbers within the error are equal
    actual_line_num=$(grep -o "[Ll][Ii][Nn][Ee] [0-9]*" $actual_output | cut -d" " -f 2)

	# Temp fix. Seems to be some weird spacing issues that I dont want to deal with right now
	echo $expected_line_num > $expected_line_num.out
	echo $actual_line_num > $actual_line_num.out
	diff_out=$(diff -w -B $expected_line_num.out $actual_line_num.out)
	rm -f $expected_line_num.out
	rm -f $actual_line_num.out
	if [ "$diff_out" != "" ]; then
		echo "diff output = $diff_out"
		return 1
	fi
	return 0
}

#######################################
# Prints a message indicating that a single testcase has failed
#
# Arguments:
#	testcase: String name of the testcase that has failed
#	msg 	: String indicating the reason for why the testcase failed
#	print	: String boolean inidicating whether to output failed message
# Post-Cond	: If print is "true", a red error with a message displayed.
#			: If print is "false", nothing is displayed
#######################################
function failed_msg() {
    testcase_name=$1
    msg=$2
    print=$3
    if [ "$print" = "true" ]; then
        printf "\n${RED}*******************************\n"
        printf "* TESTCASE ${NCN}'$testcase_name' ${RED} FAILED\n"
        printf "*\n" 
        printf "$msg"
        printf "\n${RED}*******************************${NC}"
    fi
}

#######################################
# Prints a message indicating that a single testcase has passed
#
# Arguments:
#	testcase: String name of the testcase that has passed
#	print	: String boolean inidicating whether to output pass message
# Post-Cond	: If print is "true", a green message is displayed
#			: If print is "false", nothing is displayed
#######################################
function pass_msg() {
    testcase_name=$1
    print=$2
    if [ "$print" = "true" ]; then
        printf "\n${GRN}*******************************\n"
        printf "* TESTCASE ${NCN}'$testcase_name' ${GRN} PASSED\n"
        printf "${GRN}*******************************${NC}"
    fi
}

#######################################
# Checks whether actual error output matches an expected error output
#
# Arguments:
#	expected_err_out_file: 	The error output that the actual error output should match
#	actual_err_out_file:	The error output from execution of a testcase
# Returns:
#	"":		If the actual and expected error outputs are equal, have no diff
#	String:	A string containing all the information on why the two
#			error outputs are not equal
#######################################
function valid_err_output() {
	expected_err_file=$1
	actual_err_file=$2
	output_msg=""
	# Checking for an expected error output and actual program error output
    if [[ -s $actual_err_file && -s $expected_err_file ]]; then
		equal_error_line $expected_err_file $actual_err_file
		line_chck_output=$?
		if [ "$line_chck_output" -ne 0 ]; then 
			printf "line error $line_chck_output"	
            output_msg="Expected Error Line Number Does Not Match Actual Error Line Number"
        fi
    elif [ -s "$actual_err_file" ]; then # The program should not produced errors, but it did.
        echo "Expected No Error Output. Actual Error Output Produced."
    elif [ -s "$expected_err_file" ]; then # The program should have produced errors, but it did not.
        echo "Expected An Error Output. No Actual Error Output Produced."
	else
		return 0
    fi
	return 1
}

#######################################
# Checks whether actual output matches an expected output
#
# Arguments:
#	expected_out_file: 	The output that the actual output should match
#	actual_out_file:	The output from execution of a testcase
# Returns:
#	"":		If the actual and expected outputs are equal, have no diff
#	String:	A string containing all the information on why the two
#			outputs are not equal
#######################################
function valid_output() {
	expected_out_file=$1
	actual_out_file=$2
	output_msg=""
    if [[ -f "$expected_out_file" && -f "$actual_out_file" ]]; then
        diff_output=$(diff -w -B $expected_out_file $actual_out_file)
        if [[ "$diff_output" != "" ]]; then
			# If the only thing in diff is that exit status ignore as
			# this will only be used later within the script
			if [ "$(echo "$diff_output" | grep -o "status.*")" == "" ]; then
                output_msg="<<<< diff (Program Standard Output Top) >>>"
                output_msg="${output_msg}${diff_output}\n"
            fi
        fi
    elif [[ -s "$actual_out_file" && ! -f "$expected_out_file" ]]; then
        output_msg="${output_msg}Expected No Output. Actual Output Was Produced." 
    elif [ -f "$expected_out_file" ]; then
        output_msg="${output_msg}Expected Output. No Actual Output was Produced."
	else
		echo ""
		return 0
    fi
	echo "$output_msg"
	return 1
}

# Runs one testcase
# PARAMETERS: 	$1 - String: path to the testcases <./path/to/testcases/>
#				$2 - String: executable name <scanner>
#				$3 - Boolean: print testcase result information (Failed/Passed, diff, etc...)
function run_testcase() {
	testcase=$1		# EX ./testcases/testcase1.cmm
	executable=$2 	# EX ./<exec name>
	cmdline_args=$3
	print=$4		# EX "true" or "false"

	expected_out_file=${testcase%.*}.$TEST_FILE_EXT_OUT 	# Output that is expected
	expected_err_file=${testcase%.*}.$TEST_FILE_EXT_ERR		# Error output that is expected
	actual_out_file=${testcase%.*}.tmp.$TEST_FILE_EXT_OUT 	# Output resulting from program execution
	actual_err_file=${testcase%.*}.tmp.$TEST_FILE_EXT_ERR	# Error ouutput resulting from program execution

	# Each testcase has 3 seconds to run before timeout to prevent infinite loops
	timeout 3s "./$executable" "$cmdline_args" < $testcase > $actual_out_file 2> $actual_err_file
	actual_rc=$?
	
	error_rc=0
	err_message=""
	# Checking that the error outputs matched
	err_output_msg="$(valid_err_output $expected_err_file $actual_err_file)"
	if [ "$err_output_msg" != "" ]; then
		err_message="${err_message}$err_output_msg"
		error_rc=1
	fi

	# Checking that the stdout output matches
	output_msg="$(valid_output $expected_out_file $actual_out_file)"
	if [ "$output_msg" != "" ]; then
		err_message="${err_message}\n$output_msg"
		error_rc=$((error_rc+2)) # adding 2 to identify that there was an error with the output
	fi

	# Checking that the return codes match
	expected_rc=0
	if [ -s "$expected_err_file" ]; then
		expected_rc="$(tail -n 1 $expected_err_file | grep -o "[0-9]*")"
	fi
	if [ "$actual_rc" != "$expected_rc" ]; then
        err_message="${err_message}\nExpected a return code of '$expected_rc'. Actual return code '$actual_rc'\n"
		error_rc=$((error_rc+4))
	fi

    # Print pass/fail message
    if [ "$error_rc" -ne 0 ]; then
		failed_msg "$(basename $testcase)" "$err_message" $print
		# If error code is 1, then there was only a difference in error ouput
		# If the error code is 2, then there was only a difference in output
		# Because of this you can remove one of the temp outputs
		# DONT EVEN ASK ME WHAT I AM DOING HERE, WILL CHANGE IN FUTURE
		if [ $error_rc -eq 1 ]; then
			rm -f $actual_out_file
		elif [ $error_rc -eq 5 ]; then
			rm -f $actual_out_file
		elif [ $error_rc -eq 2 ]; then
			rm -f $actual_err_file
		elif [ $error_rc -eq 6 ]; then
			rm -f $actual_err_file
		fi
    else
		pass_msg "$(basename $testcase)" $print
		rm -f $actual_err_file
		rm -f $actual_out_file
    fi
	attempts=$((attempts+1))
	return "$error_rc"
}

#######################################
# Prints out the statistics of how many testcases ran, passed,
# failed, and the resulting score.
# 
# Globals:
#	attempts: Integer representing the number of testcases ran
#	pass	: Integer representing the number of testcases passing
# Post-Cond : The statistics displaying passed and failed, with proper
#				coloring, because colors are fun and easy to read.
#######################################
function print_report() {
	failed=$(( attempts-pass ))

	printf "\n${BRN}***********************************\n"
	printf "*		Overall Report\n"
	printf "*\n"
	printf "* attempts:	$attempts\n"
	printf "* passed:	${GRN}$pass${BRN}\n"

	# Print the number of testcases failed only if at least one has failed
	if [[ $failed -ne 0 ]]; then
		printf "* failed:	${RED}$failed${BRN}\n"
	fi
	printf "*\n"

	# Following if-else statements print score, which is pass / attempts
	if [[ $attempts -eq 0 ]]; then # Zero testcases ran
		printf "${BRN}* score: \t${RED}0${BRN} \x25\n" # \x25 = '%' symbol
	else
		score=$(awk "BEGIN {print $pass / $attempts * 100}")
		score=${score%.*}
		if [[ $score -gt 80 ]]; then 
			printf "* score: \t${GRN}$score${BRN} \x25\n" # \x25 = '%' symbol
		elif [[ $score -gt 60 ]]; then
			printf "* score: \t${BRN}$score${BRN} \x25\n" # \x25 = '%' symbol
		else
			printf "${BRN}* score: \t${RED}$score${BRN} \x25\n" #\x25 = '%' symbol
		fi
	fi
	printf "***********************************${NC}"
}

# ============= Running the testcases ==================
for testcase_dir in $(ls $TESTCASES_PATH 2>/dev/null); do 
	# Getting the ini_file to load the testcase
	ini_file=$(ls $TESTCASES_PATH$testcase_dir/*.ini)
	if [ "$(grep -o "execute=true" "$ini_file")" == "" ]; then
		continue
	fi
	executable=$(grep "executable=" $ini_file | cut -d '=' -f 2)
	make_target=$(grep "target=" $ini_file | cut -d '=' -f 2)
	make_clean=$(grep "clean=" $ini_file | cut -d '=' -f 2)
	print=$(grep "print=" $ini_file | cut -d '=' -f 2)
	cmdline_args=$(grep "cmdline_args=" $ini_file | cut -d '=' -f 2)

	### DONT TOUCH NICHOLAS ###
	run_make "$make_target" "$make_clean"
	run_dir_testcases "$TESTCASES_PATH$testcase_dir" "$executable" "$cmdline_args" "$print"
	(make "$make_clean") >/dev/null
done

print_report
exit 0
