#!/usr/bin/env bash

## EDITAR ESTA SECCIÓN

ASSEMBLY=flye.fasta
PREFIX=r10
NPROC=30
READS_NANO=/media3/lucia/zymo_mock_community/Zymo-GridION-EVEN-3Peaks-R103-merged.fq.gz
MEDAKA_MODEL=r103_min_high_g345
MP_PARAMS=/media3/lucia/zymo_mock_community/marginPolish/params/allParams.np.microbial.r103g324.json
HELEN_MODEL=/media3/lucia/zymo_mock_community/helen-models/HELEN_r103_guppy_microbial.pkl
REF_DIR_ILL=/media3/lucia/zymo_mock_community/illumina_ref_asm/bac/
METAQUAST_OUTDIR=ill
## flags, cambiar a false lo que no quiera correr
raconflag=false
medakaflag=false
marginflag=false
metaquastflag=false
buscoflag=false

# -----------------------------

##polishing con racon
if [ $raconflag == true ]; then
    minimap2 -ax map-ont -t ${NPROC} ${ASSEMBLY} ${READS_NANO} > ${PREFIX}-map1.sam
    racon -t ${NPROC} ${READS_NANO} ${PREFIX}-map1.sam ${ASSEMBLY} > ${PREFIX}-racon_r1.fasta
    minimap2 -ax map-ont -t ${NPROC} ${PREFIX}-racon_r1.fasta ${READS_NANO} > ${PREFIX}-map2.sam
    racon -t ${NPROC} ${READS_NANO} ${PREFIX}-map2.sam ${PREFIX}-racon_r1.fasta > ${PREFIX}-racon_r2.fasta
fi

## polishing con medaka
if [ $medakaflag == true ]; then
    medaka_consensus -i ${READS_NANO} -d ${PREFIX}-racon_r1.fasta -o ${PREFIX}-r1-medaka -m ${MEDAKA_MODEL} -t ${NPROC}
    mv ${PREFIX}-r1-medaka/consensus.fasta ${PREFIX}-r1-medaka.fasta
    medaka_consensus -i ${READS_NANO} -d ${PREFIX}-racon_r2.fasta -o ${PREFIX}-r2-medaka -m ${MEDAKA_MODEL} -t ${NPROC}
    mv ${PREFIX}-r2-medaka/consensus.fasta ${PREFIX}-r2-medaka.fasta
fi

##polishing con marginPolish/helen
if [ $marginflag == true ]; then
	if [ -f ${PREFIX}-map1.sam ]; then
	    samtools view -T ${ASSEMBLY} -F 2308 -Sb ${PREFIX}-map1.sam | samtools sort -@ ${NPROC} - -o ${ASSEMBLY}.bam
	else
		minimap2 -ax map-ont -t ${NPROC} ${ASSEMBLY} ${READS_NANO} | samtools view -T ${ASSEMBLY} -F 2308 -b - |
			samtools sort -@ ${NPROC} -o ${ASSEMBLY}.bam
	fi
    samtools index -@ ${NPROC} ${ASSEMBLY}.bam
    mkdir ${PREFIX}-margin
    marginPolish ${ASSEMBLY}.bam ${ASSEMBLY} ${MP_PARAMS} -t ${NPROC} -o ${PREFIX}-margin -f
    helen polish -i ${PREFIX}-margin/ -m ${HELEN_MODEL} -b 128 -w 4 -t 8 -o ./ -p ${PREFIX}-marginhelen
    mv ${PREFIX}-margin/output.fa ${PREFIX}-margin.fasta
    mv ${PREFIX}-marginhelen.fa ${PREFIX}-marginhelen.fasta
fi

##evaluacion con metaquast
if [ $metaquastflag == true ]; then
	if [ $buscoflag == true ]; then
		busco=-b
	fi
    metaquast.py ${busco} --no-icarus --fragmented --min-identity 90 --min-contig 5000 \
        --threads ${NPROC} -r ${REF_DIR_ILL} -o metaquast-${METAQUAST_OUTDIR} *.fasta
fi
