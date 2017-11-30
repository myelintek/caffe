#!/usr/bin/perl

# parse log with tag

#open(IN,$ARGV[0]) or die "can't open file!\n";

# 3 level hash of rank, iter, and key
#my @h_time;

die "Usage: $0 [max_iter] < [File]" if @ARGV != 1 ;

my $iter_max = $ARGV[0];
my $n_iter;
my $i = 0;
my $start_mon= 0;
my $prev_day= 0;


print STDERR "Paser:\n";
#while(my $line = <IN>){
while(my $line = <STDIN>){
    
    if($i % 100 == 0){
        print STDERR "\rLine=$i";
    }
    $i++;
    my ($h, $m, $s, $us, $rank, $iter, $type, $name);
    # get string and parse it
    if($line =~ /\w(\d\d)(\d\d)\s+(\d+)\:(\d+)\:(\d+)\.(\d+)\s+\d+\s+.+\s+\[(\w+)\]\[(\w+)\]\[(\w+)\](\[.+\]\w+)[#]+/){
    #if($line =~ /\w+\s+(\d+)\:(\d+)\:(\d+)\.(\d+)\s+\d+\s+.+\s+(\[\w+\])(\[\w+\])(\[\w+\])(\[\w+\]\w+)[#]+/){
        ($mon, $day, $hour, $m, $s, $us, $rank, $iter, $type, $name) = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
    }else{next;}
    
    if($iter > $iter_max+50){last;}
    if($iter >= $iter_max){next;}

    #my @tmp = split '', $iter; pop @tmp; shift @tmp; $iter = join '',@tmp;
    if(!exists $h_time{$rank}{'iter'}){$h_time{$rank}{'iter'} = 0};
    # compose of mius

    # handle month change
    if($start_mon == 0){$start_mon = $mon;}
    if($start_mon == $mon){
        $prev_day = $day;
    }elsif($start_mon == $mon-1){
        $day+=$prev_day;
    }else{
        die "Error: the program can't support timestamps accros through 2 months!\n";
    }

    my $time = ((($day*24+$hour)*60 + $m)*60 + $s)* 1000000 + $us;
    
    # key string
    my $key = "$type $name";
    if($iter > $n_iter){$n_iter = $iter;}

    #print "$rank $iter $time $key ",$h_time{$rank}{'iter'},"\n";

    # if some iter data is too old, it means that all data were readed, it might can be output.

    #if( $h_time{$rank}{'iter'}+3 < $iter ) {
         #print "aaa\n";
    #     &print_output(\%h_time, $rank, $h_time{$rank}{'iter'});
    #}

    # store value
    $h_time{$rank}{$iter}{"$key"} = $time;
}
print STDERR "\rLine=$i";
print STDERR "\n";
#close(IN);

# output the rest
for my $rank (keys %h_time){
    while($n_iter >= $h_time{$rank}{'iter'}){
         &print_output(\%h_time, $rank, $h_time{$rank}{'iter'});}}

#    print $h_time{$rank}{'iter'},"\n";


# print hash content of (rank, iter)
# remove the data had been printed
sub print_output{
    my ($hash_ref, $rank, $iter) = @_;
    my %hash = %$hash_ref;
    #print "$hash_ref, $rank $iter\n";
    # fetch iter data, sort it, output it
    my @arr = keys $hash{$rank}{$iter};
    my @arr2 = values $hash{$rank}{$iter};
    #print join "\n", @arr,"\n";
    my @idx = sort { $arr2[$a] <=> $arr2[$b] } 0 .. $#arr2;
    @arr = @arr[@idx], @arr2 = @arr2[@idx];
    for(my $i = 0 ; $i <= $#arr ; $i++){print $rank, " ", $iter, " ", $arr2[$i], " ", $arr[$i],"\n";}

    # remove iter data which are already outputed, it might save some memory.
    for (keys $hash{$rank}{$iter}){delete $hash{$rank}{$iter}{$_}}; delete $hash{$rank}{$iter};

    # update iter
    #$hash{$rank}{'iter'} = int($hash{$rank}{'iter'})+1;
    $hash{$rank}{'iter'}++;
    
}



