#! /bin/bash

# ====================================================================
# ============== ONLY EDIT THE FOLLOWING VARIABLES ===================
# ====================================================================
racket_loc="/mnt/c/Program Files/Racket/" # Location of racket folder

# Finding the exectuable based off the main Racket folder. For people
# who cannot do it themselves.
for exec_loc in "${racket_loc}"Racket.*; do
	racket_loc=$exec_loc
done
#racket_loc="/usr/racket/bin"						# May be where racket is on linux, to lazy to check.

rkt_exec="funs.rkt"									# Name of the .rkt file
input_file="./testcases/${rkt_exec%.*}.in"			# Default input file name is the executable name plus .in
expected_output="./testcases/${rkt_exec%.*}.out"	# Default expected out file name is executable name plus .out
expected_err_output="./testcases/${rkt_exec%.*}.err" # Default expected err rile name is executable name plus .err

# ====================================================================
# ========== NOTHING BELOW THIS LINE SHOULD NEED EDITING =============
# ====================================================================

# =================== Variables Need Throughout ======================
# ====================================================================
RED='\033[0;31m'
GRN='\033[0;32m'
BRN='\033[0;33m'
NC='\033[0m'


tmp_out="awk_tmp_out" 						# Used when stripping values from output and src files
tmp_rkt_out="${expected_output%.*}.out.tmp" # Temp out file used later for diff checking to expected output
tmp_rkt_err_out="${expected_err_output%.*}.err.tmp" 

tmp_input_file="${input_file%.*}.orig.in.tmp"
cat $input_file > $tmp_input_file
tmp_expected_out="${expected_output%.*}.orig.out.tmp"
cat $expected_output > $tmp_expected_out

tmp_expected_err_out="${expected_err_output%.*}.orig.err.tmp"
if [[ -s $expected_err_output ]]; then
	cat $expected_err_output > $tmp_expected_err_out
fi

# ====================== Formatting Input File =======================
# Need to prepend (enter! <rkt file>) inorder for proper execution
# ====================================================================
if [[ $(awk '/enter!.*/' $tmp_input_file) == "" ]]; then
	enter_cmd="(enter! \"$rkt_exec\")"
	echo "$enter_cmd" | cat - $tmp_input_file > $tmp_out && mv $tmp_out $tmp_input_file
fi

# Removes all comments from the file
awk '{gsub(/;.*$/, "")}1' $tmp_input_file > $tmp_out && mv $tmp_out $tmp_input_file
awk NF $tmp_input_file > $tmp_out && mv $tmp_out $tmp_input_file # Removes all empty lines

# =============== Formatting Expectd File ======================
# Need to remove all comments and spaces from the expected err output
# file in order to make diff happy
# ====================================================================
awk '{gsub(/;.*$/, "")}1' $tmp_expected_out > $tmp_out && mv $tmp_out $tmp_expected_out
# Strip carriage returns
awk '{gsub(/\r/,"")}1' $tmp_expected_out > $tmp_out && mv $tmp_out $tmp_expected_out
awk NF $tmp_expected_out > $tmp_out && mv $tmp_out $tmp_expected_out # Removes all empty lines


# ============== Formatting Expected Error File =====================
# Need to remove all comments and spaces from the expected output
# file in order to make diff happy
# ====================================================================
if [[ -s $tmp_expected_err_out ]]; then
	awk '{gsub(/;.*$/, "")}1' $tmp_expected_err_out > $tmp_out && mv $tmp_out $tmp_expected_err_out
	# Strip carriage returns
	awk '{gsub(/\r/,"")}1' $tmp_expected_err_out > $tmp_out && mv $tmp_out $tmp_expected_err_out
	awk NF $tmp_expected_err_out > $tmp_out && mv $tmp_out $tmp_expected_err_out # Removes all empty lines
fi

# ======================== Running The Testcase ======================
# ====================================================================
printf "\n${BRN}----- RUNNING TESTCASE -----${NC}\n"
cat $tmp_input_file | "${racket_loc}" -f $rkt_exec -i > $tmp_rkt_out 2> $tmp_rkt_err_out

# ================== Cleaning Racket Ouput ====================
# Stripping all the garbage off the program output do to stupid racket 
# output adding trash every where, thanks for that racket developers!!!!
# =============================================================
# Strip the Welcome message
awk '{gsub(/Welcome to Racket.*$/, "")}1' $tmp_rkt_out > $tmp_out && mv $tmp_out $tmp_rkt_out
# Strip away the '> '
awk '{gsub(/.*> /, "")}1' $tmp_rkt_out > $tmp_out && mv $tmp_out $tmp_rkt_out
# Strip carriage returns and empty lines
awk '{gsub(/\r/,"")}1' $tmp_rkt_out > $tmp_out && mv $tmp_out $tmp_rkt_out
awk NF $tmp_rkt_out > $tmp_out && mv $tmp_out $tmp_rkt_out


# ============= Cleaning Racket Error Ouput ===================
# Stripping all the garbage off the program output do to stupid racket 
# output adding trash every where, thanks for that racket developers!!!!
# =============================================================
# Strip away the '> '
grep -o ';[^[]*\+' $tmp_rkt_err_out > $tmp_out && mv $tmp_out $tmp_rkt_err_out
awk '{gsub(/.*; /, "")}1' $tmp_rkt_err_out > $tmp_out && mv $tmp_out $tmp_rkt_err_out
# Strip carriage returns and empty lines
awk NF $tmp_rkt_err_out > $tmp_out && mv $tmp_out $tmp_rkt_err_out

rm -f $tmp_out

# ======= Setting Functions for Display Testcase Results ======
# Helps prevent stupid output clutter, which seems to build up
# quite alot with these, what seem to be easy, scripts. 
# The reason for this is probably because I have no idea 
# what I am doing.
# =============================================================
function failed_output() {
	tc_file=$1
	diff_file=$2
	diff_out=$3
	printf "\n${RED}*******************************\n"
	printf "* TESCASE ${NC}'$tc_file' ${RED}FAILED\n"
	printf "*\n"
	printf "* DIFF File: $diff_file\n"
	printf "*\n"
	printf "* DIFF OUTPUT - (Program Output Top)\n"
	printf "$diff_out"
	printf "\n*******************************${NC}\n"
}

function pass_output() {
	tc_file=$1
	printf "\n${GRN}*******************************\n"
	printf "* TESCASE ${NC}'$tc_file' ${GRN}PASSED\n"
	printf "*******************************${NC}\n"
}

# ======== Starting Diff On Actual vs. Expected Output ========
# This is normal output from the execution of the program
# AKA: What you usually see if using dr. racket, the "IDE" for
# 		complete noobs!!! COMMAND LINE ALL THE WAY (jj:wq)
# =============================================================
return_code=0
return_msg=""

output_diff_file="${expected_output%.*}.out.diff"
diff -b -w $tmp_rkt_out $tmp_expected_out > $output_diff_file
if [[ -s $output_diff_file ]]; then
	# NOT EMPTY
	return_msg="${return_msg}$(cat $output_diff_file)\n"
	return_code=1
fi

# ==== Starting Diff On Actual vs. Expected Error Output ======
# This is all errors returned by your either great defense code
# or in my case, the terrible code that always breaks, such as
# what is about to follow. :)
# =============================================================
if [[ -s $tmp_rkt_err_out && -s $tmp_expected_err_out ]]; then
	# Both error files, expected and acutal, exists 
	err_diff_file="${expected_err_output%.*}.err.diff"
	diff -b -w $tmp_rkt_err_out $tmp_expected_err_out > $err_diff_file
	if [[ -s $err_diff_file ]]; then
		# NOT EMPTY
		return_msg="${return_msg}$(cat $err_diff_file)\n"
		return_code=$((return_code+2))
	fi

	if [ "$return_code" -eq 0 ]; then
		pass_output $rkt_exec
		rm -f $output_diff_file
		rm -f $err_diff_file
	else
		# Removing either output_diff or err_diff if one of the diffs did not differ
		if [ "$return_code" -eq 2 ]; then
			rm -f $output_diff_file
			failed_output $rkt_exec "$err_diff_file" "$return_msg"
		elif [ "$return_code" -eq 1 ]; then
			printf "HI removing $err_diff_file"
			rm -f $err_diff_file
			failed_output $rkt_exec "$output_diff_file" "$return_msg"
		else
			failed_output $rkt_exec "${output_diff_file}\n\t${output_diff_file}" "$return_msg"
		fi
	fi
else
	failed_output $rkt_exec "n/a" "Error exists when it is not suppose to or\nError ouput does not exist when it is suppose to"
fi

# Cleaning dirty laundry, you know how it is
rm -f $tmp_rkt_out
rm -f $tmp_rkt_err_out
rm -f $tmp_input_file
rm -f $tmp_expected_out
rm -f $tmp_expected_err_out

printf "\n"
