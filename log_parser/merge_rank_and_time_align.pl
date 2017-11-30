#!/usr/bin/perl
# merge log of same rank number
# align time

#open(IN, $ARGV[0]) or die "can't open file\n";

my %hash;
my $min_time = 0;
my @lines = <STDIN>;
print STDERR "Merge:\n";
#while(my $line = <IN>){
for my $line(@lines){
    chomp $line;
    my @col = split /\s+/, $line;
    my ($rank, $iter, $time, $type, $name) = @col;

#    if($iter % 100 == 0){
        print STDERR "\rRank=$rank Iter=$iter  ";
#    }

    $min_time = $time if $min_time == 0;
    $min_time = $time if $min_time > $time;

    if(!exists $hash{$rank}){
        $hash{$rank} = ();
    } 
    push @{$hash{$rank}}, $line;
}

print STDERR "\n";

for my $rank (sort %hash){
    for(@{$hash{$rank}}){
        my @col = split /\s+/, $_;
        my ($rank, $iter, $time, $type, $name) = @col;
        $time -= $min_time;
        print "$rank $iter $time $type $name\n";
    }
}


