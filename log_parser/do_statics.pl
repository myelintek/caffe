#!/usr/bin/perl

#open(IN, $ARGV[0]) or die "can't open file\n";
#@lines = <IN>;
@lines = <STDIN>;

my %hash;
print STDERR "Statics:\n";

for (my $i = 0 ; $i <= $#lines ; $i+=2){
	$line = $lines[$i+1];
    chomp $line;
    @col = split /\s+/, $line;
    ($rank, $iter, $time, $type, $name) = @col;

#    if($iter % 100 == 0){
        print STDERR "\rRank=$rank Iter=$iter  ";
#    }
    if (!exists $hash{$rank}{"$type $name"}){
    	$hash{$rank}{"$type $name"} = ();
    	if (!exists $hash{$rank}{'name_order'}){
    		$hash{$rank}{'name_order'} = ();
    	}
    	push @{$hash{$rank}{'name_order'}}, "$type $name";
    }

    push @{$hash{$rank}{"$type $name"}}, $time;

}
print sprintf("%8s\t%8s\t%12.6s\t%12.6s\t%12.6s\t%-10s\t(Unit: Sec.)\n", 'Rank', 'Count', 'Sum', 'Avg', 'Mse','Name');
for my $rank (sort keys %hash){
	for my $typename (@{$hash{$rank}{'name_order'}}){
		my $sum = 0;
		my $count = 0;
		for (@{$hash{$rank}{$typename}}){
            $sum += $_/1000000;
            $count ++;
        }
        my $avg = $sum/$count;
        my $mse = 0;
        for (@{$hash{$rank}{$typename}}){
            $mse += (($_ / 1000000 - $avg)**2);
            #print $mse,"\n";
        }
        $mse = $mse / $count;
        $mse = sqrt($mse);
        print sprintf("% 8d\t% 8d\t%12.6f\t%12.6f\t%12.6f\t%-10s\n", $rank, $count, $sum, $avg, $mse, $typename);
        #print "$rank\t$type\t$name\t$count\t$sum\t$avg\t$mse\n";
	}
}

print STDERR "\n";
