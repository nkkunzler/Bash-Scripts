#! /bin/bash

export LC_ALL="en_US.UTF-8"

# ============ Should only edit the things between here ============
# ==================================================================

WD="./" # working dirctory

TESTCASES_PATH="${WD}testcases/"

TEST_FILE_EXT_IN="cmm" # Testcase input that has extension .cmm
TEST_FILE_EXT_OUT="out"
TEST_FILE_EXT_ERR="err"

# ==================================================================
# GOTO Line 230 in order to add a new testcase suite
# ==================================================================

rc=0 # Return Code, 0 for no failed testcases / 1 for 1+ failed testcases
attempts=0
pass=0

RED='\033[0;31m'
BRN='\033[0;33m'
GRN='\033[0;32m'
NC='\033[0m\n'
NCN='\033[0m'

# Checks that the make file contains the parameter to make the exectuble and clean
function check_makefile() {
	make_param=$1 # Used to generate the executable
	clean_param=$2 # Used to clean the result of running make
	(cd ${WD} && make $make_param) >/dev/null 2>/dev/null # Calling the make file
	if [[ $? -ne 0 ]]; then # Warnings or errors in compilling
        printf "\n\t\t${RED}"
		printf "***** ERROR *****\n"	
		printf "\tProgram contains WARNINGS / ERRORS!\n"
		(cd ${WD} && make $make_param)
		printf "\tExiting test script!${NC}\n"
		exit 1
	fi
	(cd ${WD} && make $clean_param) >/dev/null 2>/dev/null
	if [[ $? -ne 0 ]]; then # Warnings or errors in compilling
        printf "\n\t\t${RED}"
		printf "***** ERROR *****\n"	
		printf "\tMakefile does NOT contain '$clean_param'\n"
		printf "\tExiting test script!${NC}"
		exit 1
	fi
}

#Message indicating a failed testcase directory
function failed_dir_testcase() {
	printf "\n${RED}*****************************************************\n"
	printf "* TESTCASES IN DIRECTORY ${NCN}'$1' ${RED}FAILED\n"
	printf "*****************************************************${NC}"
}

# Message indicating a passed testcase directory
function passed_dir_testcase() {
	printf "\n${GRN}****************************************************\n"
	printf "* ALL TESTCASES IN DIRECTORY ${NCN}'$1' ${GRN}PASSED\n"
	printf "****************************************************${NC}"
}

# Runs all the testscases within a specific directory
function run_testcases_in_dir() {
	dir_path=$1
	driver=$2
	make_param=$3
	make_clean=$4
	print=$5 # true / false

	check_makefile $make_param $make_clean_param
	(cd ${WD} && make $make_param) >/dev/null 
	printf "\n${BRN}----- Running testcases in directory '$(basename $dir_path)' -----${NC}"

	er_code=0 # Error code
	for testcase in $(ls ${dir_path}*.${TEST_FILE_EXT_IN} 2>/dev/null) # Getting each testcase
	do
		run_testcase $testcase $driver $print
        tc_rc=$?
        if [ "$tc_rc" -ne 0 ]; then
            er_code=$tc_rc
        else
            pass=$((pass+1))
        fi
	done

	if [ "$print" = false ]; then
		if [[ "$er_code" -eq 0 ]]; then 
			passed_dir_testcase $(basename $dir_path)
		else
			failed_dir_testcase $(basename $dir_path)
		fi
	fi
	(cd ${WD} && make $make_clean) >/dev/null
} 

# Returns the line number in which an error occured
function get_err_line_num() {
    return $(grep -o "[Ll][Ii][Nn][Ee] [0-9]*" <<< "$1" | cut -d" " -f2)
}

# Determines if the errors thrown by the testcase input matches the expected output
function matching_errors() {
    file1=$1 # Expected error output file
    file2=$2 # Actual error output file

    error_regex="";
    line_num_regex='(E|e)(R|r)(R|r)(O|o)(R|r)*(L|l)(I|i)(N|n)(E|e)*$'

    f1_line_num="";
    f2_line_num="";
    while IFS= read -r f1_line && IFS= read -r f2_line <&3;
    do
        if [[ $f1_line =~ $error_regex && $f2_line =~ $error_regex ]]; then
            f1_line_num=$(get_err_line_num $f1_line)
            f2_line_num=$(get_err_line_num $f2_line)
            if [[ $f1_line_num != $f2_line_num ]]; then
                return 1
            fi
        fi
    done <$file1 3<$file2
    return 0
}

function failed_msg() {
    tc_name=$1
    tc_message=$2
    failed_print_msg=$3
    if [ "$failed_print_msg" = true ]; then
        printf "\n${RED}*******************************\n"
        printf "* TESTCASE ${NCN}'$tc_name' ${RED} FAILED\n"
        printf "*\n" 
        printf "* $tc_message\n"
        printf "${RED}*******************************${NC}"
    fi
}

function pass_msg() {
    tc_name=$1
    pass_print_msg=$2
    if [ "$pass_print_msg" = true ]; then
        printf "\n${GRN}*******************************\n"
        printf "* TESTCASE ${NCN}'$tc_name' ${GRN} PASSED\n"
        printf "${GRN}*******************************${NC}"
    fi
}

# Runs one testcase
# PARAMETERS: 	$1 - String: path to the testcases <./path/to/testcases/>
#				$2 - String: executable name <scanner>
#				$3 - Boolean: print testcase result information (Failed/Passed, diff, etc...)
function run_testcase() {
	attempts=$((attempts+1))
	run_tc_path=$1
	run_tc=$(basename $run_tc_path)
	run_exec=$2
	run_print=$3
	run_err_code=0

    output_msg="" 

	expected_out_file=${run_tc_path%.*}.$TEST_FILE_EXT_OUT
	temp_out_file=${run_tc_path%.*}.tmp.$TEST_FILE_EXT_OUT
	expected_err_file=${run_tc_path%.*}.$TEST_FILE_EXT_ERR
	temp_err_file=${run_tc_path%.*}.tmp.$TEST_FILE_EXT_ERR

	# Each testcase has 3 second to run before timeout
	timeout 3s ./$run_exec < $run_tc_path > $temp_out_file 2> $temp_err_file
	testcase_return=$?

    expected_err_code=0
    # Program produced an error output and an expected error output file is given
    if [[ -s "$temp_err_file" && -s "$expected_err_file" ]]; then
        expected_err_code=$(tac $expected_err_file | awk 'NF{print $NF; exit}')
        has_matching_errs=$(matching_errors $expected_err_file $temp_err_file)      
        if [[ "$has_matching_errs" -ne 0 ]]; then # Return of 1 indicates no matching error files
            output_msg="Error produced does not match expected error\n"
            run_err_code=1
        fi
    elif [ -s "$temp_err_file" ]; then
        output_msg="${output_msg}Expected no error output, however, output was produced.\n"
        run_err_code=1
    elif [ -s "$expected_err_file" ]; then
        output_msg="${output_msg}Expected error output, however, none was produced.\n"
        run_err_code=1
    fi


    # Testing .out diff
    if [[ -f "$expected_out_file" && -f "$temp_out_file" ]]; then
        diff_output=$(diff $expected_out_file $temp_out_file)
        if [[ "$diff_output" != "" ]]; then
            if ! [[ "$diff_output" =~ 'exit status' ]]; then
                output_msg="${output_msg}<<<< diff (Program Output Top) >>>\n"
                output_msg="${output_msg} ${diff_output}"
                run_err_code=1
            fi
        fi
    elif [[ -s "$temp_out_file" && ! -f "$expected_out_file" ]]; then
        output_msg="${output_msg}Output was produced. Expected no output.\n"
        run_err_code=1
    elif [ -f "$expected_out_file" ]; then
        output_msg="${output_msg} Expected program output. None produced.\n"
        run_err_code=1
    fi

    # Test exit code
    if [ "$testcase_return" -ne $expected_err_code ]; then
        output_msg="${output_msg} Expected a return code of '$expected_err_code'. Actual '$testcase_return'\n"
        run_err_code=1
    fi

    # Print pass/fail message
    if [ "$run_err_code" -ne 0 ]; then
        failed_msg $run_tc "${output_msg}" $print
    else
        pass_msg $run_tc $print
		rm -f $temp_out_file
		rm -f $temp_err_file
    fi

	return "$run_err_code"
}

# Prints out the stats of all the testcases that ran
function print_report() {
	failed=$(( attempts-pass ))

	printf "\n${BRN}***********************************\n"
	printf "*		Overall Report\n"
	printf "*\n"
	printf "* attempts:	$attempts\n"
	printf "* passed:	${GRN}$pass${BRN}\n"
	if [[ $failed -ne 0 ]]; then
		printf "* failed:	${RED}$failed${BRN}\n"
	fi
	printf "*\n"
	if [[ $attempts -eq 0 ]]; then
		printf "${BRN}* score: \t${RED}0${BRN} \x25\n" # No testcases run
	else
		score=$(awk "BEGIN {print $pass / $attempts * 100}")
		score=${score%.*}
		if [[ $score -gt 80 ]]; then
			printf "* score: \t${GRN}$score${BRN} \x25\n"
		elif [[ $score -gt 60 ]]; then
			printf "* score: \t${BRN}$score${BRN} \x25\n"
		else
			printf "${BRN}* score: \t${RED}$score${BRN} \x25\n"
		fi
	fi
	printf "***********************************${NC}"
	return $rc
}


# ============= Compiling the C code ==============
#clear # Clear the terminal
printf "\n${BRN} *** ITS RECOMMENDED TO HAVE -Wall and -Werror Enabled ***\n"
printf "\n${BRN}----- Compiling C Code -----${NC}"

# Touch all files
for C_FILE in $(ls ${WD}*.c 2>/dev/null); do
	touch ${C_FILE}
done

# ============= Running the testcases ==================
# Parameters <testcase_path> <make param> <executable name> <make clean name> <print_output>

# Assignment 1 Milestone 1 Testcase Runner
run_testcases_in_dir \
	"${TESTCASES_PATH}assg1_m1_testcases/" \
	"scanner" \
	"scanner" \
	"clean_scanner" \
	false 				

# Assignment 1 Milestone 2 Testcase Runner
run_testcases_in_dir \
	"${TESTCASES_PATH}assg1_m2_testcases/" \
	"compile" \
	"compile" \
	"clean" \
	false

# Assignment 2 Milestone 1 Testcase Runner
run_testcases_in_dir \
	"${TESTCASES_PATH}assg2_m1_testcases/" \
	"compile" \
	"compile" \
	"clean" \
	true

print_report # printing
