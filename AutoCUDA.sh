#! /bin/bash

get_results() {
  # Stats parsing
  GFLOPS=$(grep "Gigaflops" current.out | cut -d'=' -f2 | sed 's/[[:space:]]//g')
  TEXEC=$(grep "Elapsed time of the loop" current.out | cut -d'=' -f2 | sed 's/[[:space:]]//g' | sed 's/(s)//g')

  printf "$1,$2,$TEXEC,$GFLOPS\n" >> results.csv
}

# Check command line input
if test $# -ne 1;
then
  echo "Argument mismatch! Usage: $0 path-to-executable"
  exit 1
fi

EXEC=$1
printf "K1 with 1D blocks,,,\n" > results.csv
printf "X-size,Y-size,Time,Gflops\n" >> results.csv

# Check if the given executable exists
if ! test -f $EXEC;
then
  echo "$EXEC is not a valid executable file! Exiting."
  exit 3
fi

# Execute tests for configuration: K1 with 1D blocks
i=8

printf "K1 with 1D blocks,,,\n"
while test $i -le 1024;
do
  export BS="BLOCK_SIZE_X_K0=$i"
  make

  if test $? -ne 0;
  then
    echo "Compilation failure (K1, block size: $i)! Exiting."
    exit 2
  fi

  for j in $(seq 1 10);
  do
    $EXEC -c GPU -gpu-k 1 > current.out
    get_results $i 1
  done

  i=$(expr $i \* 2)
done

printf ",,,\n,,,\n" >> results.csv
printf "K2 with 2D blocks,,,\n"
printf "K2 with 2D blocks,,,\n" >> results.csv
printf "X-size,Y-size,Time,Gflops\n" >> results.csv

# Execute tests for configuration: K2 with 2D blocks
i=2
j_init=512

while test $i -le 1024;
do
  if test $i -eq 1024;
  then
    i=1023
  fi

  j=$j_init

  while test $j -ge 2;
  do
    if test $i -ge 8 || test $j -ge 8;
    then
      export BS="BLOCK_SIZE_X_K1=$i -DBLOCK_SIZE_Y_K1=$j"
      make

      if test $? -ne 0;
      then
        echo "Compilation failure (K2, block size X: $i, block size Y: $j)! Exiting."
        exit 2
      fi

      for k in $(seq 1 10);
      do
        $EXEC -c GPU -gpu-k 2 > current.out
        get_results $i $j
      done
    fi

    j=$(expr $j \/ 2)
  done

  j_init=$(expr $j_init \/ 2)
  i=$(expr $i \* 2)
done

printf ",,,\n,,,\n" >> results.csv
printf "K4 with 2D blocks,,,\n"
printf "K4 with 2D blocks,,,\n" >> results.csv
printf "X-size,Y-size,Time,Gflops\n" >> results.csv

# Execute tests for configuration: K4 with 2D blocks
i=8

while test $i -le 32;
do
  export BS="BLOCK_SIZE_XY_K3=$i"
  make

  if test $? -ne 0;
  then
    echo "Compilation failure (K2, block size X: $i, block size Y: $i)! Exiting."
    exit 2
  fi

  for k in $(seq 1 10);
  do
    ./MatrixProduct -c GPU -gpu-k 4 > current.out
    get_results $i $i
  done

  i=$(expr $i \* 2)
done

printf ",,,\n,,,\n" >> results.csv
echo "Tests completed."
exit 0
