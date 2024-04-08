#!/bin/bash
#SBATCH -c32
#SBATCH --mem=110g
#SBATCH --gres=lscratch:200
#SBATCH --time=12:0:0

#D15 sample took 8.5 h, 32 cpu and 91 GB.
#The mouse data finished ~146 samples in 12 hours.
set -e
module load parallel minimap2/2.26 sambamba/0.8.2
sample=$1
mkdir -p temp_bam bam
find AGA0018_1/fastq_pass2/ -type f -name "*fastq.gz" | parallel -j 10 -I% --max-args 1 --tag "minimap2 -a -x map-ont -Y -t 3 -R "@RG\\\\tLB:nisc\\\\tID:AGA0018_1\\\\tSM:$sample" /data/OGL/resources/genomes/mm39/genome.mmi % | sambamba sort -u --compression-level 6 --tmpdir=/lscratch/$SLURM_JOB_ID -t 3 -o %.bam <(sambamba view -S -f bam --compression-level 0 -t 3 /dev/stdin)"
#bam files generated in the fastq_pass folder
find AGA0018_1/fastq_pass2/ -type f -name "*.bam" -exec mv {} temp_bam \;
find AGA0018_1/fastq_pass2/ -type f -name "*.bam.bai" -exec mv {} temp_bam \;
#The minimap2 index were generated by: cd /data/OGL/resources/genomes
#ln -s /fdb/genome/mm39/chr_all.fa mm39
#minimap2 -d genome.mmi chr_all.fa


#-x map-ont: saw secondary alignment. Did not see secondary alignment when -x map-ont not set previously. 