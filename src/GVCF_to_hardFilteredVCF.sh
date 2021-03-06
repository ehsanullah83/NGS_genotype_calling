#!/bin/bash

module load GATK/3.5-0

gvcfs_list=$1
output_vcf_name=$2
ped=$3
exome_bait_bed=$4
git_repo_url="$( git --git-dir=/home/mcgaugheyd/git/NGS_genotype_calling/.git config --get remote.origin.url )"
git_commit="$( git --git-dir=/home/mcgaugheyd/git/NGS_genotype_calling/.git rev-parse --short HEAD )"

# Make sure we are on the master branch
git_dir="$( git --git-dir=/home/mcgaugheyd/git/NGS_genotype_calling/.git config --get remote.origin.url )"
if [[ "$git_branch" -ne master ]]; then
    echo $git_dir not on master!!!
    exit 1
fi

# Merges all GVCFs into a VCF
GATK -m 20g GenotypeGVCFs \
	-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	-o $2 \
	-V $gvcfs_list \
	--pedigree $ped

if [[ $4 -eq 0 ]]; then
	# Extracts all SNPs
	GATK -m 20g SelectVariants \
		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
		-V $2 \
		-selectType SNP \
		-o ${2%.vcf.gz}.rawSNP.vcf.gz

	# Extracts all INDELS
	GATK -m 20g SelectVariants \
		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
		-V $2 \
		--interval_padding 100 \
		-selectType INDEL \
		-o ${2%.vcf.gz}.rawINDEL.vcf.gz
# if bed provided, then limit extractionn to those regions
else
	# Extracts all SNPs
	GATK -m 20g SelectVariants \
		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
		-V $2 \
		-L $4 \
   		--interval_padding 100 \
		-selectType SNP \
		-o ${2%.vcf.gz}.rawSNP.vcf.gz

	# Extracts all INDELS
	GATK -m 20g SelectVariants \
		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
		-V $2 \
		-L $4 \
		--interval_padding 100 \
		-selectType INDEL \
		-o ${2%.vcf.gz}.rawINDEL.vcf.gz
fi

# Hard filters on GATK best practices for SNPs with MQ mod from bcbio
GATK -m 20g VariantFiltration \
	-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	-V ${2%.vcf.gz}.rawSNP.vcf.gz \
	--filterExpression "QD < 2.0 || FS > 60.0 || MQ < 30.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0" \
	--filterName "FAIL_McGaughey_SNP_filter_v01" \
	-o ${2%.vcf.gz}.hardFilterSNP.vcf.gz

# Hard filters on GATK bests for INDELs
GATK -m 20g VariantFiltration \
	-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	-V ${2%.vcf.gz}.rawINDEL.vcf.gz \
	--filterExpression "QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0" \
	--filterName "FAIL_McGaughey_INDEL_filter_v01" \
	-o ${2%.vcf.gz}.hardFilterINDEL.vcf.gz
	
GATK -m 20g CombineVariants \
	-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	--variant ${2%.vcf.gz}.hardFilterSNP.vcf.gz \
	--variant ${2%.vcf.gz}.hardFilterINDEL.vcf.gz \
	-o ${2%.vcf.gz}.hardFilterSNP-INDEL.vcf.gz \
	--genotypemergeoption UNSORTED

# phase by transmission
GATK -m 20g PhaseByTransmission \
    -R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
    -V ${2%.vcf.gz}.hardFilterSNP-INDEL.vcf.gz \
    -ped $3 \
    -o ${2%.vcf.gz}.hardFilterSNP-INDEL.PBT.vcf.gz

# delete intermediate files
rm ${2%.vcf.gz}.rawSNP.vcf.gz*
rm ${2%.vcf.gz}.rawINDEL.vcf.gz*
rm ${2%.vcf.gz}.hardFilterSNP.vcf.gz*
rm ${2%.vcf.gz}.hardFilterINDEL.vcf.gz*
rm ${2%.vcf.gz}.hardFilterSNP-INDEL.vcf.gz*

# add git repo url and commit info to vcf 
if [[ $git_repo_url && $git_commit ]]; then
	/home/mcgaugheyd/git/NGS_genotype_calling/src/add_gitCommit_tag_to_GVCF.sh \
		${2%.vcf.gz}.hardFilterSNP-INDEL.vcf.gz \
		$git_repo_url \
		$git_commit
fi






