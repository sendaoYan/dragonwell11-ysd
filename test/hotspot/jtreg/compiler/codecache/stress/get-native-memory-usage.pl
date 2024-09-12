#!/usr/bin/perl -w
# Copyright (c) 2024 Alibaba Group Holding Limited. All Rights Reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This code is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 only, as
# published by the Free Software Foundation.
#
# This code is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# version 2 for more details (a copy is included in the LICENSE file that
# accompanied this code).
#
# You should have received a copy of the GNU General Public License version
# 2 along with this work; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
# or visit www.oracle.com if you need additional information or have any
# questions.
#usage: perl ${TESTSRC}/get-native-memory-usage.pl `ls *-native_memory-summary.log | sort -n | xargs`
use strict;
use warnings;
use POSIX;
use File::Path qw(make_path);
my $verbose = 0;

die "please input more than 2 jcmd native log files" if( @ARGV < 2 );
my $baseline = parserJcmdResult(shift(@ARGV));
my @nameArray;
my %resultCsv;
my %resultMaxValue;
my %resultMaxIndex;
my %resultMinValue;
my %resultMinIndex;
my %resultQuarterValue;
my $plotDataDir = "plot-data";
my $lastFile = $ARGV[-1];
$lastFile =~ /^([0-9]+)-.*?/;
my $lastIndex = $1;
my $quarterIndex = ceil($lastIndex / 4);
die "lastIndex undefine!" if( ! defined $lastIndex );

foreach my $key ( sort keys %$baseline )
{
    my $value = $baseline->{$key};
    print("first line : $key : $value\n") if( $verbose > 1 );
    push @nameArray, $key;
    $resultCsv{$key} = "$key" . "," . "$value";
    $resultMaxIndex{$key} = 0;
    $resultMaxValue{$key} = $value;
    $resultMinIndex{$key} = 0;
    $resultMinValue{$key} = $value;
}
foreach my $file ( @ARGV )
{
    $file =~ /^([0-9]+)-.*?/;
    my $index = $1;
    die "index undefine!" if( ! defined $index );
    my $data = parserJcmdResult($file);
    foreach my $key ( sort @nameArray )
    {
        my $value = $data->{$key};
        print("$index : $key : $value\n") if( $verbose > 1 );
        $resultCsv{$key} = $resultCsv{$key} . "," . "$value";
        if( $value > $resultMaxValue{$key} )
        {
            $resultMaxIndex{$key} = $index;
            $resultMaxValue{$key} = $value;
        }
        if( $value < $resultMinValue{$key} )
        {
            $resultMinIndex{$key} = $index;
            $resultMinValue{$key} = $value;
        }
        if( $index == $quarterIndex )
        {
            $resultQuarterValue{$key} = $value;
        }
    }
}

if( ! -d $plotDataDir )
{
    make_path($plotDataDir);
}

open(my $csvFh, ">native-memory-summary.csv");
open(my $summaryFh, ">native-memory-summary.txt");
print $summaryFh ("total $lastIndex files, quarter index is $quarterIndex.\n");
foreach my $key ( sort @nameArray )
{
    print $csvFh "$resultCsv{$key}\n";
    my $maxMultiple = ceil($resultMaxValue{$key} / $resultMinValue{$key});
    my $quartermultiple = ceil($resultQuarterValue{$key} / $resultMinValue{$key});
    print $summaryFh "$key\tmax=$resultMaxValue{$key},index=$resultMaxIndex{$key}\tmin=$resultMinValue{$key},index=$resultMinIndex{$key}\tquarter=$resultQuarterValue{$key}\tmax/min=$maxMultiple\tquarter/mix=$quartermultiple\n";

    #write plot data
    my @data = split /,/, $resultCsv{$key};
    my $name = shift(@data);
    my $i = 0;
    open(my $fh, ">$plotDataDir/$name.txt");
    foreach my $value ( @data )
    {
        print $fh "$i $value\n";
        $i++;
    }
    close($fh);
}
close($csvFh);
close($summaryFh);



sub parserJcmdResult
{
    my ($filename) = @_;
    my %malloc;
    my $name;
    my $number;
    open(my $fh, "<$filename") or die "Can't open file '$filename' $!";
    foreach my $line ( <$fh> )
    {
        chomp($line);
        if( $line =~ /^-\s*(.*)\s+\(/ )
        {
            $name = $1;
            $name =~ s/\s+//g;
            $number = -1;
            next;
        }
        if( $line =~ /\(malloc=([0-9]+)KB/ )
        {
            $number = $1;
            die "filename=$filename\tline=$line can't get name!\n" if( length($name) <= 0 );
            my $key = "$name" . "-malloc";
            print("name=$key\t\tnumber=$number\n") if( $verbose == 1 );
            $malloc{$key} = $number;
            next;
        }
        if( $line =~ /\(mmap:.*committed=([0-9]+)KB/ )
        {
            $number = $1;
            die "filename=$filename\tline=$line can't get name!\n" if( length($name) <= 0 );
            my $key = "$name" . "-mmap";
            print("name=$key\t\tnumber=$number\n") if( $verbose == 1 );
            $malloc{$key} = $number;
            next;
        }
    }
    close($fh);
    return \%malloc;
};
