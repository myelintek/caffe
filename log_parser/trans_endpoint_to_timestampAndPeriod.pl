#!/usr/bin/perl
# get length between start and end
# output timestamp and length

#open(IN, $ARGV[0]) or die "can't open file\n";
#@lines = <IN>;
#my $iter_handle = $ARGV[1];

@lines = <STDIN>;
my $iter_handle = $ARGV[0];

my %hash1, %hash2;

#my $rank_now = 0;

my $flag = 1;


print STDERR "Devide:\n";


#while($flag){
#$flag = 0;

for (my $i = 0 ; $i <= $#lines ; $i++){
    my $line = $lines[$i];
    chomp $line;
    my @col = split /\s+/, $line;
    my ($rank, $iter, $time, $type, $name) = @col;
#    if($rank != $rank_now){next};
#    $flag = 1;
    # iteration constraint
    if($iter_handle && $iter >= $iter_handle){next;}

#    if($iter % 100 == 0){
        print STDERR "\rRank=$rank, Iter=$iter  ";
#    }

    my $time1 = $time;
    my $line1;
    if($name =~ /(.+)START/){
        my $name = $1;
        $line1 = "$rank $iter $type $name";
        if(!exists $hash1{$rank}){$hash1{$rank} = ();} 
        if(!exists $hash2{$rank}){$hash2{$rank} = ();}
    }else{
        next;
    }

    for (my $j = $i ; $j <= $#lines ; $j++){
        my $line = $lines[$j];
        chomp $line;
        my @col = split /\s+/, $line;
        my ($rank, $iter2, $time, $type, $name) = @col;
#        if($rank != $rank_now){next};
        if($name =~ /(.+)END/){
            my $name = $1;
            if($line1 eq "$rank $iter2 $type $name"){
                my $time2 = $time - $time1;
                push @{$hash1{$rank}}, sprintf "%d\t%d\t%13d\t%s\t%s", $rank, $iter, $time1, $type, $name;
                push @{$hash2{$rank}}, sprintf "%d\t%d\t%13d\t%s\t%s", $rank, $iter2, $time2, $type, $name;
#                print $line1, "\n";
                last;
            }
        }
        if($j == $#lines || $iter2 - $iter ==3){
            #print STDERR "Warning: $line1 cannot found END\n";
            last;
        }
    }
}

for my $rank (sort %hash1){
    for(my $i = 0; $i <= $#{$hash1{$rank}} ; $i++){
        print ${$hash1{$rank}}[$i],"\n";
        print ${$hash2{$rank}}[$i],"\n";
        delete $hash1{$rank}[$i];
        delete $hash2{$rank}[$i];
    }

}

#$rank_now++;
#}

print STDERR "\n";


