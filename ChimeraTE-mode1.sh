#!/bin/bash
set -a
bash ./scripts/mode1/header.sh

function usage() {

   cat << help

USAGE:

ChimTE-mode1.sh [--mate1 <mate1_replicate1.fastq.gz,mate1_replicate2.fastq.gz>] [--mate2 <mate2_replicate1.fastq.gz,mate2_replicate2.fastq.gz>] [--genome <genome.fasta>] [--strand <rf-stranded> OR <fr-stranded>][--te <TE_insertions.gtf>] [--gene <gene_annotation.gtf>] [--project <project_name>]

#Mandatory arguments:

   --mate1                 FASTQ paired-end R1

   --mate2                 FASTQ paired-end R2

   --genome                FASTA genome sequence

   --te                    GTF/GFF with TE coordinates

   --gene                  GTF/GFF with genes coordinates

   --strand                Select "rf-stranded" if your reads are reverse->forward; or "fr-stranded" if they are forward->reverse

   --project               project name (it's the name of the directory that will be created inside projects/)

#Optional arguments:

   --window                Upstream and downstream window size (default = 3000)

   --overlap               Minimum overlap between chimeric reads and TE insertions (default = 0.5 -50%-)

   --utr                   It must be used if your gene annotation (-a | --gene) has UTR regions (default = off)

   --fpkm                  Minimum fpkm to consider a gene as expressed (default = 1)

   --coverage              Minimum coverage for chimeric transcripts detection (default = 2)

   --replicate	           Minimum recurrency of chimeric transcripts between RNA-seq replicates (default = 2)

   --threads               Number of threads (default = 6)
help
}

#parse parameteres
ARGS=""
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
re='^[0-9]+$'
THREADS="6"
WINDOW="3000"
OVERLAP="0.5"
FPKM="1"
COV="2"
REP="2"
DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

if [ "$#" -eq 0 ]; then echo -e "\n${RED}ERROR${NC}: No parameters provided! Exiting..." && usage >&2; exit 1; fi

while [[ $# -gt 0 ]]; do
	case $1 in
		--mate1)
		MATE1=$2
    if [[ -z "$MATE1" ]]; then
      echo -e "\n${RED}ERROR${NC}: --mate1 fastq files were not provided! Exiting..." && exit 0; else
        r1_samples=$(sed 's/,/\n/g' <<< "$MATE1")
        while IFS= read -r mate; do
          if [[ ! -f "$mate" ]]; then
            echo -e "\n${RED}ERROR${NC}: $mate provided with --mate1 was not found!! Exiting..." && exit 1; else
            if !(egrep -q '.fastq|.fq') <<< "$mate"; then
              echo -e "\n${RED}ERROR${NC}: Files provided with --mate1 are not in .fastq or .fq extension! Exiting..." && exit 1
            fi
          fi
        done <<< "$r1_samples"
		shift 2; fi;;

		--mate2)
		MATE2=$2
    if [[ -z "$MATE2" ]]; then
      echo -e "\n${RED}ERROR${NC}: --mate2 fastq files were not provided! Exiting..." && exit 1; else
      r2_samples=$(sed 's/,/\n/g' <<< "$MATE2")
      while IFS= read -r mate; do
        if [[ ! -f "$mate" ]]; then
          echo -e "\n${RED}ERROR${NC}: $mate provided with --mate2 was not found!! Exiting..." && exit 1; else
          if !(egrep -q '.fastq|.fq') <<< "$mate"; then
            echo -e "\n${RED}ERROR${NC}: Files provided with --mate2 are not in .fastq or .fq extension! Exiting..." && exit 1
          fi
        fi
      done <<< "$r2_samples"
		shift 2; fi;;
    --genome)
    GENOME=$2
    if [[ -z "$GENOME" ]]; then
      echo -e "\n${RED}ERROR${NC}: --genome fasta file was not provided! Exiting..." && exit 1; else
      if [[ ! -f "$GENOME" ]]; then
        echo -e "\n${RED}ERROR${NC}: $GENOME provided with --genome was not found!! Exiting..." && exit 1; else
        if !(egrep -q '.fasta|.fa') <<< "$GENOME"; then
          echo -e "\n${RED}ERROR${NC}: $GENOME provided with --genome is not in .fasta extension! Exiting..." && exit 1
        fi
      fi
    shift 2; fi;;

    --te)
    TE_ANNOTATION=$2
    if [[ -z "$TE_ANNOTATION" ]]; then
      echo -e "\n${RED}ERROR${NC}: --te .gtf/.gff file was not provided! Exiting..." && exit 1; else
      if [[ ! -f "$TE_ANNOTATION" ]]; then
        echo -e "\n${RED}ERROR${NC}: $TE_ANNOTATION provided with --te was not found!! Exiting..." && exit 1; else
        if !(egrep -q '.gff|.gtf') <<< "$TE_ANNOTATION"; then
          echo -e "\n${RED}ERROR${NC}: $TE_ANNOTATION provided with --te is not in .gtf/.gff extension! Exiting..." && exit 1
        fi
      fi
    shift 2; fi;;

    --gene)
    GENE_ANNOTATION=$2
    if [[ -z "$GENE_ANNOTATION" ]]; then
      echo -e "\n${RED}ERROR${NC}: --gene .gtf/.gff file was not provided! Exiting..." && exit 1; else
      if [[ ! -f "$GENE_ANNOTATION" ]]; then
        echo -e "\n${RED}ERROR${NC}: $GENE_ANNOTATION provided with --gene was not found!! Exiting..." && exit 1; else
        if !(egrep -q '.gff|.gtf') <<< "$GENE_ANNOTATION"; then
          echo -e "\n${RED}ERROR${NC}: $GENE_ANNOTATION provided with --gene is not in .gtf/.gff extension! Exiting..." && exit 1
        fi
      fi
    shift 2; fi;;

    --strand)
    STRANDED=$2
    if [[ -z "$STRANDED" ]]; then
      echo -e "\n${RED}ERROR${NC}: The strand-specific parameter was not selected! Please use -s | --strand (rf-stranded or fr-stranded)	Exiting..." && exit 1; else
      if [ "$STRANDED" != "rf-stranded" ] && [ "$STRANDED" != "fr-stranded" ]; then
        echo -e "\n${RED}ERROR${NC}: The option -$STRANDED- is not accepted, please use --strand (rf-stranded or fr-stranded)	Exiting..." && exit 1
      fi
    shift 2; fi;;

    --project)
    PROJECT="$DIR"/projects/$2
    shift 2;;
    --window)
    WINDOW=$2
    if ! [[ $WINDOW =~ $re ]] ; then
      echo -e "\n${RED}ERROR${NC}: --window "$WINDOW" is not a valid value!! Use >= 200. Exiting..." &&  exit 1; else
      if [[ $WINDOW -lt "200" ]] ; then
        echo -e "\n${RED}ERROR${NC}: --window "$WINDOW" is not a valid value!! Use >= 200. Exiting..." &&  exit 1
      fi
    fi
    shift 2;;
    --overlap)
    OVERLAP=$2
    shift 2;;
    --utr)
    UTR=$#
    shift 1;;
    --fpkm)
    FPKM=$2
    if ! [[ $FPKM =~ $re ]] ; then
      echo -e "\n${RED}ERROR${NC}: --fpkm "$FPKM" is not a valid value!! Use >= 2. Exiting..." &&  exit 1; else
      if [[ $FPKM -lt "1" ]] ; then
        echo -e "\n${RED}ERROR${NC}: --fpkm "$FPKM" is not a valid value!! Use >= 2. Exiting..." &&  exit 1
      fi
    fi
    shift 2;;
    --coverage)
    COV=$2
    if ! [[ $COV =~ $re ]] ; then
      echo -e "\n${RED}ERROR${NC}: --coverage "$COV" is not a valid value!! Use >= 2. Exiting..." &&  exit 1; else
      if [[ $COV -lt "2" ]] ; then
        echo -e "\n${RED}ERROR${NC}: --coverage "$COV" is not a valid value!! Use >= 2. Exiting..." &&  exit 1
      fi
    fi
    shift 2;;
    --replicate)
    REP=$2
    if ! [[ $REP =~ $re ]] ; then
      echo -e "\n${RED}ERROR${NC}: --replicate "$REP" is not a valid value!! Use >= 2. Exiting..." &&  exit 1; else
      if [[ $REP -lt "2" ]] ; then
        echo -e "\n${YELLOW}WARNING${NC}: It's not recommended to run ChimeraTE with only one replicate!! Continuing..." && sleep 4
      fi
    fi
    shift 2;;
    --threads)
    THREADS=$2
    if ! [[ $THREADS =~ $re ]] ; then
      echo -e "\n${RED}ERROR${NC}: --threads "$THREADS" is not a valid value!! Use >= 6. Exiting..." &&  exit 1; else
      if [[ $THREADS -lt "6" ]] ; then
        echo -e "\n${RED}ERROR${NC}: --threads "$THREADS" is not a valid value!! Use >= 6. Exiting..." && exit 1
      fi
    fi
    shift 2;;
    -h | --help)
    usage
    exit 1
    ;;
    -*|--*)
    echo "Unknown option $1"
    exit 1
    ;;
    *)
    ARGS+=("$1")
    echo -e "\n${RED}ERROR${NC}: Your commandline is not valid! Check ChimeraTE usage with --help.  Exiting..." && exit 1
    shift
    ;;
esac
done

echo -e "Parameters:\n==> mate1:\t$MATE1\n==> mate2:\t$MATE2\n==> genome:\t$GENOME\n==> TE gtf:\t$TE_ANNOTATION\n==> gene gtf:\t$GENE_ANNOTATION\n==> project:\t$PROJECT\n==> window:\t$WINDOW\n==> overlap:\t$OVERLAP\n==> fpkm:\t$FPKM\n==> replicability:\t$REP"

if [[ ! -d "$PROJECT" || ! -d "$PROJECT"/tmp ]]; then
  mkdir "$PROJECT" 2>/dev/null
  mkdir "$PROJECT"/tmp 2>/dev/null; else
  echo "The project $PROJECT has been found and it won't be overwritten"
fi

r1_samples=$(sed 's/,/\n/g' <<< "$MATE1")
r2_samples=$(sed 's/,/\n/g' <<< "$MATE2")
paste <(echo "$r1_samples") <(echo "$r2_samples") --delimiters '\t' > "$PROJECT"/tmp/samples.lst

i=1; while IFS= read -r replicates; do
	mate1_rep=$(cut -f1 <<< "$replicates")
	mate2_rep=$(cut -f2 <<< "$replicates")
  sample="replicate${i}"

  mkdir "$PROJECT"/"$sample" "$PROJECT"/"$sample"/TE_info "$PROJECT"/"$sample"/gene_info "$PROJECT"/"$sample"/alignment "$PROJECT"/"$sample"/tmp "$PROJECT"/"$sample"/gene_info/tmp "$PROJECT"/"$sample"/plot 2>/dev/null
  echo -e "$replicates" > $PROJECT/$sample/replicate${i}_libraries.txt
  let i=i+1
  export TMP="$PROJECT"/"$sample"/gene_info/tmp ALN="$PROJECT"/"$sample"/alignment BAM_FILE="$PROJECT"/"$sample"/alignment/accepted_hits.bam TE_info="$PROJECT"/"$sample"/TE_info GENE_info="$PROJECT"/"$sample"/gene_info

  echo -e "\n---------------------------->> Running strd_specific.sh - Genome alignment with $sample <<----------------------------"
  ./scripts/mode1/strd_specific.sh

  echo -e "---------------------------->> Running exp_TEs.sh - Identifying expressed TE insertions in $sample <<----------------------------\n"
  ./scripts/mode1/exp_TEs.sh

  echo -e "---------------------------->> Running te-initiated-search.sh  - Searching for TE-initiated transcripts in $sample <<----------------------------\n"
  ./scripts/mode1/te-initiated-search.sh

  echo -e "---------------------------->> Running te-terminated-search.sh  - Searching for TE-terminated transcripts in $sample <<----------------------------\n"
  ./scripts/mode1/te-terminated-search.sh

  echo -e "---------------------------->> Running te-exonized-search.sh  - Searching for TE-exonized transcripts in $sample <<----------------------------\n"
  ./scripts/mode1/te-exonized-search.sh

done < "$PROJECT"/tmp/samples.lst

echo -e "---------------------------->> Running replicability-mode1.sh  - Searching for chimeras identified in at least $REP replicates <<----------------------------\n"
./scripts/mode1/replicability-mode1.sh

echo -e "\nThe process has finished successfully"
