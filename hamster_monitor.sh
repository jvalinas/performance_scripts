#!/bin/sh

# Wanted trigger timeout in milliseconds.
IDLE_TIME=$((10*60*1000)) # 10 min

# Time to stop tracking
END_HOUR='18:00'

# Prefered category
PREFERED_CATEGORY='Day-to-day'

# Internal parameters
TFORMAT='%Y-%m-%d %H:%M:%S'
HAMSTER_CMD="hamster"

# Sequence to execute when timeout triggers.
task_selector() {
    stopped_task=$($HAMSTER_CMD current | awk '{print $3}')

    items=($($HAMSTER_CMD activities | grep "@$PREFERED_CATEGORY" | tac | awk -F"@" '{print $1 "\n" $2}') )
    
    IFS=$'\n'
    current_items=($($HAMSTER_CMD list | grep "|" | awk -F"|" 'NR>1 {print $4 "@" $5}' | tac))
    for item in ${current_items[@]}; do
            values=($(echo $item | tr "@" "\n"))
            task=${values[0]}
            cat=${values[1]}
            cat="$(echo -e "${cat}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

            if [ "$cat" != "$PREFERED_CATEGORY" ]; then
        	    items+=($task)
        	    items+=($cat)
            fi
    done
    IFS=$'\n'
    opt=$(zenity --list --title="Hamster wrapper" --text="What have you been doing?(Esc to continue with $stopped_task)" --separator='|' --column='task' --width=600 --height=450 --column='category' ${items[@]})
    unset IFS
    
    if [ -z "$opt" ]; then
	    task_name=$(zenity --entry --title="Hamster wrapper" --text="Maybe something different? (Esc to continue with $stopped_task)" --width=600)
        if [ -z "$task_name" ]; then
	    # No task select
	    task_name="$stopped_task"
	fi
    else
	# Task selected from the list
        task_name=$(echo $opt | cut -d'|' -f 1)
    fi

    if [ ! -z "$task_name" ]; then
        end_date=$(date +"$TFORMAT")
	start_date=$( date -d @$(( $start_date_epoch - $IDLE_TIME/1000 )) +"$TFORMAT" )
	$HAMSTER_CMD track "$task_name" "$start_date" "$end_date"
    fi
    $HAMSTER_CMD start "$stopped_task"
}

new_task () {
  current_task=$(hcurrent) 
  text="Morning! What are you doing today?"
  if [ -z "$1" ]; then
    value=$(zenity --entry --title="Hamster wrapper" --text="$text")
  else
    value="$@"
  fi
  if [ ! -z "$value" ]; then
      hamster start $value
      echo "Task \"$value\" started."
  fi
}

trigger_cmd() {
    start_date_epoch=$(date +'%s')

    time_to_stop=$(( $(date -d "$END_HOUR" +%s) - $(date -d $(date +%H:%M) +%s) ))
    if [ "$time_to_stop" -gt "0" ]; then
	# Still in working hours
        task_selector
    else
	$HAMSTER_CMD stop

	# Out of office
	zenity --question --title="Hasmter wrapper" --text="Have you been working? \n(Esc -> No, Enter -> Yes)"
	if [ "$?" -eq "0" ]; then
	   task_selector
	else
	   new_task
	fi
    fi
}

sleep_time=$IDLE_TIME

# ceil() instead of floor()
while sleep $(((sleep_time+999)/1000)); do
    idle=$(xprintidle)
    if [ $idle -ge $IDLE_TIME ]; then
        trigger_cmd
        sleep_time=$IDLE_TIME
    else
        # Give 100 ms buffer to avoid frantic loops shortly before triggers.
        sleep_time=$((IDLE_TIME-idle+100))
    fi
done
