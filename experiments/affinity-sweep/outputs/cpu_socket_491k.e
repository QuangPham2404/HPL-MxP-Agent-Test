Loading nvhpc/26.3
  Loading requirement: gnu/gcc-12.3 cuda/13.1
WARNING: group: unknown groupid 1304617061
libnuma: Warning: cpu argument 55 out of range

usage: numactl [--all | -a] [--balancing | -b] [--interleave= | -i <nodes>]
		[--preferred= | -p <node>] [--preferred-many= | -P <nodes>]
               [--physcpubind= | -C <cpus>] [--cpunodebind= | -N <nodes>]
               [--membind= | -m <nodes>] [--localalloc | -l] command args ...
               [--localalloc | -l] command args ...
       numactl [--show | -s]
       numactl [--hardware | -H] [--cpu-compress]
       numactl [--version]
       numactl [--length | -L <length>] [--offset | -o <offset>] [--shmmode | -M <shmmode>]
               [--strict | -t]
               [--shmid | -I <id>] --shm | -S <shmkeyfile>
               [--shmid | -I <id>] --file | -f <tmpfsfile>
               [--huge | -u] [--touch | -T] 
               memory policy [--dump | -d] [--dump-nodes | -D]

memory policy is --interleave | -i, --preferred | -p, --membind | -m, --localalloc | -l
<nodes> is a comma delimited list of node numbers or A-B ranges or all.
Instead of a number a node can also be:
  netdev:DEV the node connected to network device DEV
  file:PATH  the node the block device of path is connected to
  ip:HOST    the node of the network device host routes through
  block:PATH the node of block device path
  pci:[seg:]bus:dev[:func] The node of a PCI device
<cpus> is a comma delimited list of cpu numbers or A-B ranges or all
all ranges can be inverted with !
all numbers and ranges can be made cpuset-relative with +
the old --cpubind argument is deprecated.
use --cpunodebind or --physcpubind instead
use --balancing | -b to enable Linux kernel NUMA balancing
for the process if it is supported by kernel
<length> can have g (GB), m (MB) or k (KB) suffixes
--------------------------------------------------------------------------
Primary job  terminated normally, but 1 process returned
a non-zero exit code. Per user-direction, the job has been aborted.
--------------------------------------------------------------------------
libnuma: Warning: cpu argument 55 out of range

usage: numactl [--all | -a] [--balancing | -b] [--interleave= | -i <nodes>]
		[--preferred= | -p <node>] [--preferred-many= | -P <nodes>]
               [--physcpubind= | -C <cpus>] [--cpunodebind= | -N <nodes>]
               [--membind= | -m <nodes>] [--localalloc | -l] command args ...
               [--localalloc | -l] command args ...
       numactl [--show | -s]
       numactl [--hardware | -H] [--cpu-compress]
       numactl [--version]
       numactl [--length | -L <length>] [--offset | -o <offset>] [--shmmode | -M <shmmode>]
               [--strict | -t]
               [--shmid | -I <id>] --shm | -S <shmkeyfile>
               [--shmid | -I <id>] --file | -f <tmpfsfile>
               [--huge | -u] [--touch | -T] 
               memory policy [--dump | -d] [--dump-nodes | -D]

memory policy is --interleave | -i, --preferred | -p, --membind | -m, --localalloc | -l
<nodes> is a comma delimited list of node numbers or A-B ranges or all.
Instead of a number a node can also be:
  netdev:DEV the node connected to network device DEV
  file:PATH  the node the block device of path is connected to
  ip:HOST    the node of the network device host routes through
  block:PATH the node of block device path
  pci:[seg:]bus:dev[:func] The node of a PCI device
<cpus> is a comma delimited list of cpu numbers or A-B ranges or all
all ranges can be inverted with !
all numbers and ranges can be made cpuset-relative with +
the old --cpubind argument is deprecated.
use --cpunodebind or --physcpubind instead
use --balancing | -b to enable Linux kernel NUMA balancing
for the process if it is supported by kernel
<length> can have g (GB), m (MB) or k (KB) suffixes
--------------------------------------------------------------------------
mpirun detected that one or more processes exited with non-zero status, thus causing
the job to be terminated. The first process to do so was:

  Process name: [[35492,1],3]
  Exit code:    1
--------------------------------------------------------------------------
