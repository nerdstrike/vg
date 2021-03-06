#!/usr/bin/env bash

BASH_TAP_ROOT=../deps/bash-tap
. ../deps/bash-tap/bash-tap-bootstrap

PATH=../bin:$PATH # for vg


plan tests 11

vg construct -r small/x.fa >j.vg
vg index -x j.xg j.vg
vg construct -r small/x.fa -v small/x.vcf.gz >x.vg
vg index -s -k 11 -d x.idx x.vg
vg index -x x.xg x.vg

is $(vg map -r <(vg sim -s 1337 -n 100 -x j.xg) -d x.idx | vg surject -p x -d x.idx -t 1 - | vg view -a - | jq .score | grep 100 | wc -l) \
    100 "vg surject works perfectly for perfect reads derived from the reference"
    
is $(vg map -r <(vg sim -s 1337 -n 100 -x j.xg) -d x.idx | vg surject -p x -d x.idx -t 1 -s - | grep -v "@" | cut -f3 | grep x | wc -l) \
    100 "vg surject actually places reads on the correct path"

is $(vg map -r <(vg sim -s 1337 -n 100 -x x.xg) -d x.idx | vg surject -p x -d x.idx -t 1 - | vg view -a - | wc -l) \
    100 "vg surject works for every read simulated from a dense graph"

is $(vg map -r <(vg sim -s 1337 -n 100 -x x.xg) -d x.idx | vg surject -p x -d x.idx -s - | grep -v ^@ | wc -l) \
    100 "vg surject produces valid SAM output"
    
is $(vg map -r <(vg sim -s 1337 -n 100 -x j.xg) -d x.idx -J | jq '.name = "Alignment"' | vg view -JGa - | vg surject -p x -d x.idx - | vg view -aj - | jq -c 'select(.name)' | wc -l) \
    100 "vg surject retains read names"

# These sequences have edits in them, so we can test CIGAR reversal as well
SEQ="ACCGTCATCTTCAAGTTTGAAAATTGCATCTCAAATCTAAGACCCAGAGGGCTCACCCAGAGTCGAGGCTCAAGGACAGCTCTCCTTTGTGTCCAGAGTG"
SEQ_RC="CACTCTGGACACAAAGGAGAGCTGTCCTTGAGCCTCGACTCTGGGTGAGCCCTCTGGGTCTTAGATTTGAGATGCAATTTTCAAACTTGAAGATGACGGT"

is "$(vg map -s $SEQ -d x.idx | vg surject -p x -d x.idx - -s | cut -f1,3,4,5,6,7,8,9,10)" "$(vg map -s $SEQ_RC -d x.idx | vg surject -p x -d x.idx - -s | cut -f1,3,4,5,6,7,8,9,10)" "forward and reverse orientations of a read produce the same surjected SAM, ignoring flags"

is $(vg map -r <(vg sim -s 1337 -n 100 -x x.xg) -d x.idx | vg surject -p x -d x.idx -b - | samtools view - | wc -l) \
    100 "vg surject produces valid BAM output"

#is $(vg map -r <(vg sim -s 1337 -n 100 x.vg) x.vg | vg surject -p x -d x.idx -c - | samtools view - | wc -l) \
#    100 "vg surject produces valid CRAM output"

rm -rf j.vg x.vg x.idx j.xg x.xg

vg index -s -k 27 -e 7 -d f.idx graphs/fail.vg

read=TTCCTGTGTTTATTAGCCATGCCTAGAGTGGGATGCGCCATTGGTCATCTTCTGGCCCCTGTTGTCGGCATGTAACTTAATACCACAACCAGGCATAGGTGAAAGATTGGAGGAAAGATGAGTGACAGCATCAACTTCTCTCACAACCTAG
is $(vg map -s $read -d f.idx | vg surject -i graphs/GRCh37.path_names -d f.idx -s - | grep $read | wc -l) 1 "surjection works for a longer (151bp) read"

rm -rf f.idx

vg index -s -k 27 -e 7 -d f.idx graphs/fail2.vg

read=TATTTACGGCGGGGGCCCACCTTTGACCCTTTTTTTTTTTCAAGCAGAAGACGGCATACGAGATCACTTCGAGAGATCGGTCTCGGCATTCCTGCTGAACCGCTCTTCCGATCTACCCTAACCCTAACCCCAACCCCTAACCCTAACCCCA
is $(vg map -s $read -d f.idx | vg surject -i graphs/GRCh37.path_names -d f.idx -s - | grep $read | wc -l) 1 "surjection works for another difficult read"

rm -rf f.idx

vg construct -r minigiab/q.fa -v minigiab/NA12878.chr22.tiny.giab.vcf.gz >minigiab.vg
vg index -s -k 11 -d m.idx minigiab.vg
is $(vg map -b minigiab/NA12878.chr22.tiny.bam -d m.idx | vg surject -d m.idx -s - | grep chr22.bin8.cram:166:6027 | grep BBBBBFBFI | wc -l) 1 "mapping reproduces qualities from BAM input"
is $(vg map -f minigiab/NA12878.chr22.tiny.fq.gz -d m.idx | vg surject -d m.idx -s - | grep chr22.bin8.cram:166:6027 | grep BBBBBFBFI | wc -l) 1 "mapping reproduces qualities from fastq input"
rm -rf minigiab.vg* m.idx
