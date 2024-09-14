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
#usage: perl -w ${TESTSRC}/check-native-memory-usage.pl "Code-malloc:2.6,Code-mmap:2.8,Compiler-malloc:4.6" `ls *-native_memory-summary.log | sort -n | xargs`
use strict;
use warnings;
use POSIX;
my $verbose = 0;

die "please input rules and more than 2 jcmd native log files" if( @ARGV < 3 );
my $rules = shift @ARGV;
my $lastIndexResultHash = parserJcmdResult(pop(@ARGV));
my $thirdIndexResultHash = parserJcmdResult($ARGV[ceil(scalar(@ARGV)/3)]);

foreach my $rule ( split /,/, $rules )
{
    print("rule: $rule\n");
    my($moduleName, $coefficient) = split /:/, $rule;
    print("$moduleName: $coefficient\n") if( $verbose > 3 );
    my $lastIndexValue = $lastIndexResultHash->{$moduleName};
    my $thirdIndexValue = $thirdIndexResultHash->{$moduleName};
    die "can't find $moduleName memory usage information!" if( ! defined $lastIndexValue );
    die "can't find $moduleName memory usage information!" if( ! defined $thirdIndexValue );
    my $compareValue = $thirdIndexValue * $coefficient;
    if( $lastIndexValue > $compareValue )
    {
        die "$moduleName: $lastIndexValue > $compareValue=$thirdIndexValue*$coefficient";
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
