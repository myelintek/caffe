#!/usr/bin/perl

my @lines = <STDIN>;

my %hash;
print STDERR "Summarize...:\n";

$file = $ARGV[0];
open(IN, $file);
my @net = <IN>;
close(IN);

for (my $i = 0 ; $i <= $#net ; $i++){
    my $line = $net[$i];
    if($line =~ /layer/){
        my $name, $type, $j;
        for($j = $i+1 ; $j <= $#net ; $j++){
            if($net[$j] =~ /name.*\"(.*)\"/){$name = $1;last;}
        }
        for($j = $i+1 ; $j <= $#net ; $j++){
            if($net[$j] =~ /type.*\"(.*)\"/){$type = $1;last;}
        }
        $hash{$name} = $type;
#        print "$name $type\n";
    }
}

#for(sort keys %hash){
#    print "$_ $hash{$_}\n";
#}


my %hash2;

for (my $i = 0 ; $i <= $#lines ; $i++){
    my $line = $lines[$i+1];
    chomp $line;
    @col = split /\s+/, $line;
    while($col[0] eq '' && @col){shift @col;}
    if(!@col){next;}
    ($rank, $count, $sum, $avg, $mse, $type, $layer) = @col;
    $layer = substr $layer,1,-1;
    #print "$rank $count $sum $type $layer\n";

    # remove 1
    if($layer eq 'Iteration'){next;}

    # layer: prototext contain
    if(exists $hash{$layer}){
        my $layer_type = $hash{$layer};
        $hash2{$rank}{$layer_type} += $sum;
    # layer: prototext not contain, produce by initialize automatically
    }elsif($layer =~ /.*_split/){
        $hash2{$rank}{Split} += $sum;
    # not layer: such as allreduce
    }elsif($layer =~ /.*ALLReduce/){
        $hash2{$rank}{ALLReduce} += $sum;
    }elsif($layer =~ /.*(LoadBatch.*)/){
        $hash2{$rank}{$1} += $sum;
        next;
    }else{
        $hash2{$rank}{Etc} += $sum;
    }
    $hash2{$rank}{total} += $sum;
}

for my $rank (sort keys %hash2){
    my @arr1 = keys %{$hash2{$rank}};
    my @arr2 = values %{$hash2{$rank}};
    @arr1 = @arr1[sort { $arr2[$b] <=> $arr2[$a]} 0..$#arr2 ];

    for my $layer_type (@arr1){
        #if($layer_type eq 'total'){next;}
        #print "$rank $layer_type $hash2{$rank}{$layer_type}\n";
        print sprintf("% 2s\t%-20s\t%10.6f%\t%16.6f", $rank, $layer_type, $hash2{$rank}{$layer_type}/$hash2{$rank}{total}*100, $hash2{$rank}{$layer_type}),"\n";
    }
    print "\n";
}



