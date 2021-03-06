# --------------------------------------------- #
# | Initialize stuff
# --------------------------------------------- #

# Enable command substitution in prompt
setopt prompt_subst

# Initialize prompt
autoload -Uz promptinit && promptinit

# Initialize colors
autoload -Uz colors && colors

# Hooks
autoload -U add-zsh-hook

# --------------------------------------------- #
# | Core options
# --------------------------------------------- #
BLOX_CONF__BLOCK_PREFIX="${BLOX_CONF__BLOCK_PREFIX:-[}"
BLOX_CONF__BLOCK_SUFFIX="${BLOX_CONF__BLOCK_SUFFIX:-]}"
BLOX_CONF__ONELINE="${BLOX_CONF__ONELINE:-false}"
BLOX_CONF__NEWLINE="${BLOX_CONF__NEWLINE:-true}"

# --------------------------------------------- #
# | Some charcters
# --------------------------------------------- #
BLOX_CHAR__SPACE=" "
BLOX_CHAR__NEWLINE="
"

# --------------------------------------------- #
# | Segments
# --------------------------------------------- #

# Upper
BLOX_SEG__UPPER_LEFT="${BLOX_SEG__UPPER_LEFT:-blox_block__host,blox_block__cwd,blox_block__git}"
BLOX_SEG__UPPER_RIGHT="${BLOX_SEG__UPPER_RIGHT:-blox_block__bgjobs,blox_block__ruby,blox_block__nodejs,blox_block__time}"

# Lower
BLOX_SEG__LOWER_LEFT="${BLOX_SEG__LOWER_LEFT:-blox_block__symbol}"
BLOX_SEG__LOWER_RIGHT="${BLOX_SEG__LOWER_RIGHT:-}"

# --------------------------------------------- #
# | Helper functions
# --------------------------------------------- #

# Build a given segment
function blox_helper__build_segment() {

  # The segment to build
  segment=$1
  blocks=("${(@s/,/)segment}") # Don't ask me

  # The final segment
  res=""

  # Loop on each block
  for block in $blocks; do

    # Get the block data
    blockData="$($block)"

    # Append to result
    [[ $blockData != "" ]] && [[ -n $blockData ]] && res+=" $blockData"
  done

  # Echo the result
  echo $res
}

# Calculate how many spaces we need to put
# between two strings
function blox_helper__calculate_spaces() {

  # The segments
  left=$1
  right=$2

  # The filter (to ignore ansi colors)
  local zero='%([BSUbfksu]|([FBK]|){*})'

  # Filtering
  left=${#${(S%%)left//$~zero/}}
  right=${#${(S%%)right//$~zero/}}

  # Desired spaces length
  local termwidth
  (( termwidth = ${COLUMNS} - ${left} - ${right} ))

  # Calculate spaces
  local spacing=""
  for i in {1..$termwidth}; do
    spacing="${spacing} "
  done

  # Echo'em
  echo $spacing
}

# --------------------------------------------- #
# | Hooks
# --------------------------------------------- #

# Set the title
function blox_hook__title() {

  # Show working directory in the title
  tab_label=${PWD/${HOME}/\~}
  echo -ne "\e]2;${tab_label}\a"
}

# Build the prompt
function blox_hook__build_prompt() {

  # Show working directory in the title
  tab_label=${PWD/${HOME}/\~}
  echo -ne "\e]2;${tab_label}\a"

  # The prompt consists of two part: PROMPT
  # and RPROMPT. In multiline prompt, RPROMPT goes
  # to the lower line. To solve this, we need to do stupid stuff.

  # Segments
  upper_left="$(blox_helper__build_segment $BLOX_SEG__UPPER_LEFT)"
  upper_right="$(blox_helper__build_segment $BLOX_SEG__UPPER_RIGHT) "
  lower_left="$(blox_helper__build_segment $BLOX_SEG__LOWER_LEFT)"
  lower_right="$(blox_helper__build_segment $BLOX_SEG__LOWER_RIGHT) "

  # Spacessss
  spacing="$(blox_helper__calculate_spaces ${upper_left} ${upper_right})"

  # Check if a newline char is needed
  [[ $BLOX_CONF__NEWLINE == false ]] && BLOX_CHAR__NEWLINE=""

  # In oneline mode, we set $PROMPT to the
  # upper left segment and $RPROMPT to the upper
  # right. In multiline mode, $RPROMPT goes to the bottom
  # line so we set the first line of $PROMPT to the upper segments
  # while the second line to only the the lower left. Then,
  # $RPROMPT is set to the lower right segment.

  # Check if in oneline mode
  if [[ $BLOX_CONF__ONELINE == true ]]; then

    # Setting only the upper segments
    PROMPT='${BLOX_CHAR__NEWLINE}${upper_left} '

    # Right segment
    RPROMPT='${upper_right}'
  else

    # The prompt
    PROMPT='${BLOX_CHAR__NEWLINE}${upper_left}${spacing}${upper_right}
${lower_left} '

    # Right prompt
    RPROMPT='${lower_right}'
  fi

  # PROMPT2 (continuation interactive prompt)
  PROMPT2=' ${BLOX_BLOCK__SYMBOL_ALTERNATE} %_ >>> '
}

# Async stuff (for git fetch)
ASYNC_PROC=0
function blox_hook__async() {

  function async {

    # Fetch the data from git
    is_fetchable=$(git rev-parse HEAD &> /dev/null)
    [[ is_fetchable ]] && git fetch &> /dev/null

    # Signal the parent shell to update the prompt
    kill -s USR2 $$
  }

  # Kill child if necessary
  if [[ "${ASYNC_PROC}" != 0 ]]; then
    kill -s HUP $ASYNC_PROC > /dev/null 2>&1 || :
  fi

  # Build the prompt in a background job
  async &!

  # Set process pid
  ASYNC_PROC=$!
}

# 'Catch' the async process
function TRAPUSR2 {

  # Re-build the prompt
  blox_hook__build_prompt

  # Reset process number
  ASYNC_PROC=0
}

# --------------------------------------------- #
# | Setup hooks
# --------------------------------------------- #

# Build the prompt
add-zsh-hook precmd blox_hook__build_prompt

# Start sync process
add-zsh-hook precmd blox_hook__async

# Set title
add-zsh-hook precmd blox_hook__title
