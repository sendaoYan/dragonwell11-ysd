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
#usage: ~/jdk11u-dev/test/hotspot/jtreg/compiler/codecache/stress/check-native-memory-usage.pl 10 `ls *-native_memory-summary.log | sort -n | xargs`
use strict;
use warnings;
my $verbose = 0;

die "please input multiple and more than 2 jcmd native log files" if( @ARGV < 3 );
my $multiple = shift @ARGV;
my $baseline = parserJcmdResult(shift(@ARGV));
foreach my $file ( @ARGV )
{
    my $data = parserJcmdResult($file);
    foreach my $key ( keys %$data )
    {
        my $currentValue = $data->{$key};
        my $baselineValue = $baseline->{$key};
        print("$file:$key: $currentValue -> $baselineValue\n") if($verbose == 2);
        my $coefficient = 1;        
        $coefficient = 5 if( "Code" eq "$key" );
        $coefficient = 20 if( "Class" eq "$key" );
        $coefficient = 20 if( "Module" eq "$key" );
        $coefficient = 20 if( "Synchronizer" eq "$key" );
        $coefficient = 10 if( "ArenaChunk" eq "$key" );
        my $compareValue = $baselineValue * $multiple * $coefficient;
        if( $currentValue > $compareValue )
        {
            die "$file:$key: $currentValue > $compareValue=$baselineValue*$multiple*$coefficient";
        }
    }
}

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
            print("name=$name\t\tnumber=$number\n") if( $verbose == 1 );
            $malloc{$name} = $number;
        }
    }
    close($fh);
    return \%malloc;
};
