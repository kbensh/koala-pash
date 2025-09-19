#!/bin/bash
set -x
set -e
#
# Run 5TERA preprocessing, alignment, and postprocessing
#

TOP=$(git rev-parse --show-toplevel)

outdir="$TOP/bio/outputs/teraseq"
scripts="$TOP/bio/scripts"
mkdir -p "$outdir"/fastq

. "$scripts/PARAMS.sh"

threads=6
assembly="hg38"

####################################################################################################


samples="\
hsa.dRNASeq.HeLa.polyA.CIP.decap.REL5.long.1
hsa.dRNASeq.HeLa.polyA.decap.REL5.long.1
hsa.dRNASeq.HeLa.polyA.REL5.long.1
hsa.dRNASeq.HeLa.polyA.REL5OH.long.1"

echo ">>> SANITIZE FASTQ HEADERS <<<"

for i in $samples; do
    sdir=$SAMPLE_DIR/$i
    sdiro="$outdir/$i"
    echo " Working for" $i

    mkdir -p "$sdiro"/fastq
    mkdir -p "$sdiro"/align
    mkdir -p "$sdiro"/db
    mkdir -p "$sdiro"/logfiles
    mkdir -p "$sdiro"/fast5

    zcat $sdir/fastq/reads.1.fastq.gz \
    | fastq-sanitize-header --input - --delim : --keep 0 \
    | gzip \
    > $sdiro/fastq/reads.1.sanitize.fastq.gz &
done
wait

echo ">>> REMOVE REL5 ADAPTOR <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    cutadapt \
        -g XAATGATACGGCGACCACCGAGATCTACACTCTTTCCCTACACGACGCTCTTCCGATCT \
        --overlap 31 \
        --minimum-length 25 \
        --error-rate 0.29 \
        --output $sdir/fastq/reads.1.sanitize.w_rel5.fastq.gz \
        --untrimmed-output $sdir/fastq/reads.1.sanitize.wo_rel5.fastq.gz \
        $sdir/fastq/reads.1.sanitize.fastq.gz \
        &> $sdir/logfiles/cutadapt.rel5.log &
done
wait

echo ">>> MERGE READS WITH AND WITHOUT REL5 ADAPTOR <<<"

for i in $samples; do
    sdir=$SAMPLE_DIR/$i
    echo " Working for" $i

    zcat $sdir/fastq/reads.1.sanitize.w_rel5.fastq.gz | paste - - - - | cut -f1 | sed 's/^@//g' \
        > $sdir/fastq/reads.1.sanitize.w_rel5.names.txt &
    zcat $sdir/fastq/reads.1.sanitize.wo_rel5.fastq.gz | paste - - - - | cut -f1 | sed 's/^@//g' \
        > $sdir/fastq/reads.1.sanitize.wo_rel5.names.txt &

    cat $sdir/fastq/reads.1.sanitize.w_rel5.fastq.gz $sdir/fastq/reads.1.sanitize.wo_rel5.fastq.gz \
        > $sdir/fastq/reads.1.sanitize.rel5_trim.fastq.gz &
done
wait

echo ">>> ALIGN READS TO RIBOSOMAL (ALL ENSEMBL + SILVA-HUMAN) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    minimap2 \
        -a \
        -x map-ont \
        -k 12 \
        -p 1 \
        -u f \
        -t $threads \
        --secondary=yes \
        $DATA_DIR/$assembly/minimap2.17/ensembl-transcripts-wRibo.k12.mmi \
        $sdir/fastq/reads.1.sanitize.rel5_trim.fastq.gz \
    | samtools view -b - \
    | samtools sort - \
    > $sdir/align/reads.1.sanitize.toEnsembl-transcripts-wRibo.sorted.bam

    samtools view -H $sdir/align/reads.1.sanitize.toEnsembl-transcripts-wRibo.sorted.bam > \
        $sdir/align/reads.1.sanitize.toRibosomal.sorted.sam
    samtools view -@ $threads -F4 $sdir/align/reads.1.sanitize.toEnsembl-transcripts-wRibo.sorted.bam \
        | grep -v -P "\tENST" >> $sdir/align/reads.1.sanitize.toRibosomal.sorted.sam
    rm $sdir/align/reads.1.sanitize.toEnsembl-transcripts-wRibo.sorted.bam

    cat $sdir/align/reads.1.sanitize.toRibosomal.sorted.sam | cut -f1 | sort | uniq > \
        $sdir/align/reads.1.sanitize.toRibosomal.sorted.reads.txt &

    samtools view -@ $threads -bh $sdir/align/reads.1.sanitize.toRibosomal.sorted.sam | samtools sort -@ $threads - > \
        $sdir/align/reads.1.sanitize.toRibosomal.sorted.bam

    wait
    rm $sdir/align/reads.1.sanitize.toRibosomal.sorted.sam
done
wait

echo ">>> EXTRACT NON-RIBOSOMAL READS <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    seqkit grep -nvf $sdir/align/reads.1.sanitize.toRibosomal.sorted.reads.txt \
        $sdir/fastq/reads.1.sanitize.rel5_trim.fastq.gz \
        -o $sdir/fastq/reads.1.sanitize.noribo.fastq.gz &
done
wait

echo ">>> ALIGN READS TO TRANSCRIPTOME (WITH SECONDARY) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    minimap2 \
        -a \
        -x map-ont \
        -k 12 \
        -p 1 \
        -u f \
        -t $threads \
        --secondary=yes \
        $DATA_DIR/$assembly/minimap2.17/transcripts.k12.mmi \
        $sdir/fastq/reads.1.sanitize.noribo.fastq.gz \
    | add-tag-max-sam --tag ms --newtag XP --newtag2 XN \
    | grep -v "SA:Z:" \
    | sam-count-secondary --tag X0 \
    | samtools view -b - \
    | samtools sort - \
    > $sdir/align/reads.1.sanitize.noribo.toTranscriptome-polya.sorted.bam

    ln -s $sdir/align/reads.1.sanitize.noribo.toTranscriptome-polya.sorted.bam \
    $sdir/align/reads.1.sanitize.noribo.toTranscriptome.sorted.bam
done
wait

echo ">>> ALIGN READS TO GENOME (WITH SECONDARY) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    minimap2 \
        -a \
        -x splice \
        -k 12 \
        -p 1 \
        -u b \
        -t $threads \
        --secondary=yes \
        $DATA_DIR/$assembly/minimap2.17/genome.k12.mmi \
        $sdir/fastq/reads.1.sanitize.rel5_trim.fastq.gz \
    | add-tag-max-sam --tag ms --newtag XP --newtag2 XN \
    | grep -v "SA:Z:" \
    | sam-count-secondary --tag X0 \
    | samtools view -b - \
    | samtools sort - \
    > $sdir/align/reads.1.sanitize.toGenome.sorted.bam
done
wait

echo ">>> INDEX ALIGNMENTS <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    samtools index \
        $sdir/align/reads.1.sanitize.noribo.toTranscriptome-polya.sorted.bam &
    ln -s $sdir/align/reads.1.sanitize.noribo.toTranscriptome-polya.sorted.bam.bai \
        $sdir/align/reads.1.sanitize.noribo.toTranscriptome.sorted.bam.bai
    samtools index \
        $sdir/align/reads.1.sanitize.toGenome.sorted.bam &
    wait
done

echo ">>> SAM TO SQLITE (TRANSCRIPTOME) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    cat $sdir/align/reads.1.sanitize.noribo.toTranscriptome.sorted.bam \
    | samtools view -h -F 4 -F 16 -F 2048 - \
    | sam_to_sqlite \
        --database $sdir/db/sqlite.db \
        --table transcr \
        --records_class GenOOx::Data::File::SAMminimap2::Record \
        --drop &
done
wait

echo ">>> ANNOTATE WITH GENIC ELEMENTS (TRANSCRIPTOME) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    clipseqtools-preprocess annotate_with_file \
        --database $sdir/db/sqlite.db \
        --table transcr \
        --a_file $DATA_DIR/$assembly/genic_elements.mrna.bed \
        --column coding_transcript &
done
wait

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    clipseqtools-preprocess annotate_with_file \
        --database $sdir/db/sqlite.db \
        --table transcr \
        --a_file $DATA_DIR/$assembly/genic_elements.ncrna.bed \
        --column noncoding_transcript &
done
wait

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    clipseqtools-preprocess annotate_with_file \
        --database $sdir/db/sqlite.db \
        --table transcr \
        --a_file $DATA_DIR/$assembly/genic_elements.utr5.bed \
        --column utr5 &
done
wait

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    clipseqtools-preprocess annotate_with_file \
        --database $sdir/db/sqlite.db \
        --table transcr \
        --a_file $DATA_DIR/$assembly/genic_elements.cds.bed \
        --column cds &
done
wait

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    clipseqtools-preprocess annotate_with_file \
        --database $sdir/db/sqlite.db \
        --table transcr \
        --a_file $DATA_DIR/$assembly/genic_elements.utr3.bed \
        --column utr3 &
done
wait

echo ">>> SAM TO SQLITE (GENOME) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    cat $sdir/align/reads.1.sanitize.toGenome.sorted.bam \
    | samtools view -h -F 4 -F 2048 - \
    | sam_to_sqlite \
        --database $sdir/db/sqlite.db \
        --table genome \
        --records_class GenOOx::Data::File::SAMminimap2::Record \
        --drop &
done
wait

echo ">>> ANNOTATE WITH GENIC ELEMENTS (GENOME) <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    clipseqtools-preprocess annotate_with_genic_elements \
        --database $sdir/db/sqlite.db \
        --table genome \
        --gtf $DATA_DIR/$assembly/genes-polya.gtf &
done
wait

echo ">>> ANNOTATE WITH REL5 <<<"

for i in $samples; do
    sdir=$SAMPLE_DIR/$i
    echo " Working for" $i

    echo ">> ANNOTATE WITH REL5 (TRANSCRIPTOME) <<"

    annotate-sqlite-with-fastq \
        --database $sdir/db/sqlite.db \
        --db_col_bind "qname" \
        --db_col_add "rel5" \
        --db_tables "transcr" \
        --ifile $sdir/fastq/reads.1.sanitize.w_rel5.fastq.gz

    echo ">> ANNOTATE W/WO REL5 (GENOME) <<"

    annotate-sqlite-with-fastq \
        --database $sdir/db/sqlite.db \
        --db_col_bind "qname" \
        --db_col_add "rel5" \
        --db_tables "genome" \
        --ifile $sdir/fastq/reads.1.sanitize.w_rel5.fastq.gz
done

# Note: If you have the fast5 files you can continue with the analysis. Check https://github.com/mourelatos-lab/TERA-Seq_manuscript/samples/README.md for the location where to download them.

echo ">>> NANOPOLISH POLYA <<<"

for i in $samples; do
    sdir=$outdir/$i
    echo " Working for" $i

    if [ -d "$sdir/fast5" ]; then
	    if [ `find $sdir/fast5 -maxdepth 1 -type f -name '*.fast5' | wc -l` != 0 ]; then
            nanopolish index \
                --directory $sdir/fast5/ \
                $sdir/fastq/reads.1.fastq.gz

            nanopolish polya \
                --reads $sdir/fastq/reads.1.fastq.gz \
                --bam $sdir/align/reads.1.sanitize.noribo.toTranscriptome.sorted.bam \
                --genome $DATA_DIR/$assembly/transcripts.fa \
                --threads $threads \
                > $sdir/align/reads.1.sanitize.noribo.toTranscriptome.sorted.polya.tab \
                && touch $sdir/align/nanopolish-polya.done
        else
            echo "It seems that $sdir/fast5 directory is empty. Please check you downloaded and uncompressed fast5 tar.gz archive and placed the files in $sdir/fast5."
        fi
    else
        echo "It seems that $sdir/fast5 directory doesn't exist. Please check you created $sdir/fast5, downloaded and uncompressed fast5 tar.gz and placed the files in $sdir/fast5."
    fi
done

echo ">>> ALL DONE <<<"
