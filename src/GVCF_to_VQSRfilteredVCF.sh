#!/bin/bash

module load GATK/3.5-0

gvcfs_list=$1
output_vcf_name=$2
ped=$3
bed=$4
git_repo_url="$( git --git-dir=/home/mcgaugheyd/git/NGS_genotype_calling/.git config --get remote.origin.url )"
git_commit="$( git --git-dir=/home/mcgaugheyd/git/NGS_genotype_calling/.git rev-parse --short HEAD )"

# Make sure we are on the master branch
git_dir="$( git --git-dir=/home/mcgaugheyd/git/NGS_genotype_calling/.git config --get remote.origin.url )"
if [[ "$git_branch" -ne master ]]; then
    echo $git_dir not on master!!!
    exit 1
fi

if [[ $4 -eq 0 ]]; then
	# Merges all GVCFs into a VCF
	GATK -m 8g GenotypeGVCFs \
   		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
    	-o $2 \
    	-V $gvcfs_list \
    	--pedigree $ped

	# VQSR calculation time for SNPs
	GATK -m 8g VariantRecalibrator \
    	-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
    	-input $2 \
    	-resource:hapmap,known=false,training=true,truth=true,prior=15.0 /fdb/GATK_resource_bundle/b37-2.8/hapmap_3.3.b37.vcf \
    	-resource:omni,known=false,training=true,truth=true,prior=12.0 /fdb/GATK_resource_bundle/b37-2.8/1000G_omni2.5.b37.vcf \
    	-resource:1000G,known=false,training=true,truth=false,prior=10.0 /fdb/GATK_resource_bundle/b37-2.8/1000G_phase1.snps.high_confidence.b37.vcf \
  	  	-resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /fdb/GATK_resource_bundle/b37-2.8/dbsnp_138.b37.excluding_sites_after_129.vcf  \
	   	-an DP \
	    -an QD \
 	   	-an FS \
   		-an SOR \
	    -an MQ \
	    -an MQRankSum \
	    -an ReadPosRankSum \
	    -mode SNP \
	    -tranche 100.0 -tranche 99.97 -tranche 99.9 -tranche 99.5 -tranche 99.0 -tranche 95.0 -tranche 90.0 \
	    -recalFile ${2%.vcf.gz}.recalibrate_SNP.recal \
 		-tranchesFile ${2%.vcf.gz}.recalibrate_SNP.tranches \
	    -rscriptFile ${2%.vcf.gz}.recalibrate_SNP_plots.R

	# Apply VQSR results to the variants now and output new SNP recalibrated vcf
	# GATK recommends using tranche of 99.9, bcbio recommend 99.97
	# http://bcb.io/2014/05/12/wgs-trio-variant-evaluation/
	GATK -m 8g ApplyRecalibration \
	    -R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	    -input $2 \
	    -mode SNP \
	    --ts_filter_level 99.97 \
	    -recalFile ${2%.vcf.gz}.recalibrate_SNP.recal \
	    -tranchesFile ${2%.vcf.gz}.recalibrate_SNP.tranches \
	    -o ${2%.vcf.gz}.recalibrated_snps_raw_indels.vcf.gz

	# VQSR calculation time for INDELS
	GATK -m 8g VariantRecalibrator \
		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
		-input $2 \
		-resource:mills,known=true,training=true,truth=true,prior=12.0 /fdb/GATK_resource_bundle/b37-2.8/Mills_and_1000G_gold_standard.indels.b37.vcf \
	    -an QD \
	    -an DP \
	    -an FS \
	    -an SOR \
	    -an MQRankSum \
	    -an ReadPosRankSum \
	    -mode INDEL \
	    -tranche 100.0 -tranche 99.97 -tranche 99.9 -tranche 99.5 -tranche 99.0  -tranche 98.0 -tranche 90.0 \
	    --maxGaussians 4 \
	    -recalFile ${2%.vcf.gz}.recalibrate_INDEL.recal \
	    -tranchesFile ${2%.vcf.gz}.recalibrate_INDEL.tranches \
	    -rscriptFile ${2%.vcf.gz}.recalibrate_INDEL_plots.R

	# Apply VQSR results to the variants now and output new INDEL only vcf
	# GATK recommends using tranche of 99.0, bcbio recommend 98.0
	# http://bcb.io/2014/05/12/wgs-trio-variant-evaluation/
	GATK -m 8g ApplyRecalibration \
	    -R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	    -input ${2%.vcf.gz}.recalibrated_snps_raw_indels.vcf.gz \
	    -mode INDEL \
	    --ts_filter_level 99.97 \
	    -recalFile ${2%.vcf.gz}.recalibrate_INDEL.recal \
	    -tranchesFile ${2%.vcf.gz}.recalibrate_INDEL.tranches \
	    -o ${2%.vcf.gz}.VQSR_recalibrated_variants.vcf.gz
else
	# Merges all GVCFs into a VCF
	GATK -m 8g GenotypeGVCFs \
   		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
    	-o $2 \
    	-V $gvcfs_list \
    	--pedigree $ped
		-L $4 \
        --interval_padding 100 
	# VQSR calculation time for SNPs
	GATK -m 8g VariantRecalibrator \
    	-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
    	-input $2 \
    	-resource:hapmap,known=false,training=true,truth=true,prior=15.0 /fdb/GATK_resource_bundle/b37-2.8/hapmap_3.3.b37.vcf \
    	-resource:omni,known=false,training=true,truth=true,prior=12.0 /fdb/GATK_resource_bundle/b37-2.8/1000G_omni2.5.b37.vcf \
    	-resource:1000G,known=false,training=true,truth=false,prior=10.0 /fdb/GATK_resource_bundle/b37-2.8/1000G_phase1.snps.high_confidence.b37.vcf \
  	  	-resource:dbsnp,known=true,training=false,truth=false,prior=2.0 /fdb/GATK_resource_bundle/b37-2.8/dbsnp_138.b37.excluding_sites_after_129.vcf  \
	   	-an DP \
	    -an QD \
 	   	-an FS \
   		-an SOR \
	    -an MQ \
	    -an MQRankSum \
	    -an ReadPosRankSum \
	    -mode SNP \
	    -tranche 100.0 -tranche 99.97 -tranche 99.9 -tranche 99.5 -tranche 99.0 -tranche 95.0 -tranche 90.0 \
	    -recalFile ${2%.vcf.gz}.recalibrate_SNP.recal \
 		-tranchesFile ${2%.vcf.gz}.recalibrate_SNP.tranches \
	    -rscriptFile ${2%.vcf.gz}.recalibrate_SNP_plots.R
		-L $4 \
        --interval_padding 100 
	# Apply VQSR results to the variants now and output new SNP recalibrated vcf
	# GATK recommends using tranche of 99.9, bcbio recommend 99.97
	# http://bcb.io/2014/05/12/wgs-trio-variant-evaluation/
	GATK -m 8g ApplyRecalibration \
	    -R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	    -input $2 \
	    -mode SNP \
	    --ts_filter_level 99.97 \
	    -recalFile ${2%.vcf.gz}.recalibrate_SNP.recal \
	    -tranchesFile ${2%.vcf.gz}.recalibrate_SNP.tranches \
	    -o ${2%.vcf.gz}.recalibrated_snps_raw_indels.vcf.gz
		-L $4 \
        --interval_padding 100

	# VQSR calculation time for INDELS
	GATK -m 8g VariantRecalibrator \
		-R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
		-input $2 \
		-resource:mills,known=true,training=true,truth=true,prior=12.0 /fdb/GATK_resource_bundle/b37-2.8/Mills_and_1000G_gold_standard.indels.b37.vcf \
	    -an QD \
	    -an DP \
	    -an FS \
	    -an SOR \
	    -an MQRankSum \
	    -an ReadPosRankSum \
	    -mode INDEL \
	    -tranche 100.0 -tranche 99.97 -tranche 99.9 -tranche 99.5 -tranche 99.0  -tranche 98.0 -tranche 90.0 \
	    --maxGaussians 4 \
	    -recalFile ${2%.vcf.gz}.recalibrate_INDEL.recal \
	    -tranchesFile ${2%.vcf.gz}.recalibrate_INDEL.tranches \
	    -rscriptFile ${2%.vcf.gz}.recalibrate_INDEL_plots.R
		-L $4 \
        --interval_padding 100

	# Apply VQSR results to the variants now and output new INDEL only vcf
	# GATK recommends using tranche of 99.0, bcbio recommend 98.0
	# http://bcb.io/2014/05/12/wgs-trio-variant-evaluation/
	GATK -m 8g ApplyRecalibration \
	    -R /fdb/GATK_resource_bundle/b37-2.8/human_g1k_v37_decoy.fasta \
	    -input ${2%.vcf.gz}.recalibrated_snps_raw_indels.vcf.gz \
	    -mode INDEL \
	    --ts_filter_level 99.97 \
	    -recalFile ${2%.vcf.gz}.recalibrate_INDEL.recal \
	    -tranchesFile ${2%.vcf.gz}.recalibrate_INDEL.tranches \
	    -o ${2%.vcf.gz}.VQSR_recalibrated_variants.vcf.gz
		-L $4 \
        --interval_padding 100
fi

# add git repo url and commit info to vcf
if [[ $git_repo_url && $git_commit ]]; then
    /home/mcgaugheyd/git/NGS_genotype_calling/src/add_gitCommit_tag_to_GVCF.sh \
        ${2%.vcf.gz}.hardFilterSNP-INDEL.vcf.gz \
        $git_repo_url \
        $git_commit
fi


rm ${2%.vcf.gz}.recalibrated_snps_raw_indels.vcf.gz
