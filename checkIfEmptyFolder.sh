#!/bin/bash

code_folder_with_files=0
code_not_a_folder=1
code_an_empty_folder=2
code_parameter_error=127


main()
{
  if [ $# != 1 ];then
      echo $code_parameter_error
	  return
  fi
  
  fdName=$1;
  
  if [ ! -d $fdName ]; then
      echo $code_not_a_folder
	  return
  fi
  
  if [ ! "$(ls -A $fdName)" ]; then
      echo $code_an_empty_folder
	  return
  else
      echo $code_folder_with_files
	  return
  fi
}


main $@
