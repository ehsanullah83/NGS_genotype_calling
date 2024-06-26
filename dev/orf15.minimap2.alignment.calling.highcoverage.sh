#!/bin/bash
#SBATCH -c8
#SBATCH --mem=64g
#SBATCH --gres=lscratch:50
#SBATCH --time=2:0:0

#~20 min per sample, thus adjust the time accordingly. 
#fastq files have to be SampleID-LW and SampleID-MW. If missing either LW or MW, touch an empty file.

set -e

module load minimap2/2.26 sambamba/0.8.2

mkdir -p bam

for fastq in fastq/*.fastq.gz; do
sample=$(basename $fastq | sed "s/_reads.fastq.gz//" | sed "s/.fastq.gz//" | sed "s/-/_/");
echo -e "$sample" >> manifest.csv
minimap2 -a -x map-ont -Y -t 3 -R "@RG\tLB:QBplEx\tID:$sample\tSM:$sample\tPL:ONT" /data/OGL/resources/genomes/NCBI/GRCh38Decoy/genome.mmi $fastq | sambamba sort -u --compression-level 6 --tmpdir=/lscratch/$SLURM_JOB_ID -t 3 -o bam/$sample.bam <(sambamba view -S -f bam --compression-level 0 -t 3 /dev/stdin);
done

module load clair3/1.0.4 deepvariant/1.6.0 annovar/2020-06-08

mkdir -p freebayes
mkdir -p annotation

mkdir -p deepvariant clair3 clairAnnotation

while read -r sample;
do
run_deepvariant --model_type ONT_R104 --num_shards 1 \
 --ref /data/OGL/resources/genomes/NCBI/GRCh38Decoy/genome.fa \
 --regions /data/OGL/resources/bed/RPGR_ORF15.bed \
 --reads bam/$sample.bam \
 --output_vcf deepvariant/$sample.dv.vcf.gz \
 --sample_name $sample \
 --intermediate_results_dir /lscratch/$SLURM_JOB_ID
clair3 \
  --bam_fn=bam/$sample.bam \
  --ref_fn=/data/OGL/resources/genomes/NCBI/GRCh38Decoy/genome.fa \
  --threads=8 \
  --platform=ont \
  --bed_fn=/data/OGL/resources/bed/RPGR_ORF15.bed \
  --model_path=/data/OGL/resources/clair3/ont_r1041/r1041_e82_400bps_sup_v420 \
  --sample_name=$sample \
  --output=/lscratch/$SLURM_JOB_ID \
  --var_pct_full=1 \
  --ref_pct_full=1 \
  --var_pct_phasing=1
#the last three is for amplicon sequencing, but caused missing variants in the first test run 
#Will false negative increase if setting minimum read = 1 instead of 2 as in the default???
cp /lscratch/$SLURM_JOB_ID/merge_output.vcf.gz clair3/$sample.vcf.gz
cp /lscratch/$SLURM_JOB_ID/merge_output.vcf.gz.tbi clair3/$sample.vcf.gz.tbi
convert2annovar.pl -format vcf4old clair3/$sample.vcf.gz -includeinfo --outfile clairAnnotation/$sample.avinput
ver=hg38
table_annovar.pl clairAnnotation/$sample.avinput \
$ANNOVAR_DATA/$ver \
-buildver $ver \
-remove \
-out clairAnnotation/$sample.avinput \
--protocol refGeneWithVer \
-operation g \
--argument '-hgvs' \
--polish -nastring . \
--thread 1 \
--otherinfo
sed -i "1 s/Otherinfo1\tOtherinfo2\tOtherinfo3\tOtherinfo4\tOtherinfo5\tOtherinfo6\tOtherinfo7\tOtherinfo8\tOtherinfo9\tOtherinfo10/CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tGT_FIELDS/" clairAnnotation/$sample.avinput."$ver"_multianno.txt
rm annotation/$sample.avinput
done < manifest.csv
#use bcftools normalize, VEP for proper right-alighment VEP vcf, bcftools, R 
 
#perhaps it's better to use the freebayes raw output to represent the variants, as bcftools norm may shorten the variants.

#rm annotation/$sample.avinput."$ver"_multianno.txt


#find LW/fastq -name "*fastq*" | parallel -j 10 -I% --max-args 1 --tag "minimap2 -a -Y -t 3 /data/OGL/resources/genomes/GRCh38/OPN1LW/GRCh38Decoy_OPN1LW.mmi % | sambamba sort -u --compression-level 6 --tmpdir=/lscratch/$SLURM_JOB_ID -t 3 -o %.bam <(sambamba view -S -f bam --compression-level 0 -t 3 /dev/stdin)"

#find MW/fastq -name "*fastq*" | parallel -j 10 -I% --max-args 1 --tag "minimap2 -a -Y -t 3 /data/OGL/resources/genomes/GRCh38/OPN1MW/GRCh38Decoy_OPN1MW.mmi % | sambamba sort -u --compression-level 6 --tmpdir=/lscratch/$SLURM_JOB_ID -t 3 -o MW/bam/%.bam <(sambamba view -S -f bam --compression-level 0 -t 3 /dev/stdin)"

#The minimap2 index were generated by: minimap2 -d genome.mmi  /fdb/igenomes/Homo_sapiens/NCBI/GRCh38Decoy/Sequence/WholeGenomeFasta/genome.fa 
#The index is now moved to /data/OGL/resources/genomes/NCBI/GRCh38Decoy/genome.mmi

