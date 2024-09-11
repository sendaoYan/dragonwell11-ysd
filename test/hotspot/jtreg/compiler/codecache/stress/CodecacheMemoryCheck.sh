#!/bin/bash
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

# @test
# @key stress randomness
# @summary check memory usage of optimizations and deoptimizations
# @library /test/lib /
# @modules java.base/jdk.internal.misc java.management
# @build sun.hotspot.WhiteBox compiler.codecache.stress.Helper compiler.codecache.stress.TestCaseImpl
# @build compiler.codecache.stress.UnexpectedDeoptimizationTest
# @build compiler.codecache.stress.UnexpectedDeoptimizationTestLoop
# @run driver ClassFileInstaller sun.hotspot.WhiteBox sun.hotspot.WhiteBox$WhiteBoxPermission
# @run shell/timeout=3600 CodecacheMemoryCheck.sh


# set a few environment variables so that the shell-script can run stand-alone
# in the source directory
if [ "${TESTSRC}" = "" ] ; then
  TESTSRC="."
fi
if [ "${TESTJAVA}" = "" ] ; then
  echo "TESTJAVA not set.  Test cannot execute."
  echo "FAILED!!!"
  exit 1
fi
if [ "${COMPILEJAVA}" = "" ]; then
  COMPILEJAVA="${TESTJAVA}"
fi

# set platform-dependent variables
OS=`uname -s`
case "$OS" in
  SunOS )
    PATHSEP=":"
    FILESEP="/"
    ;;
  Linux )
    PATHSEP=":"
    FILESEP="/"
    ;;
  Darwin )
    PATHSEP=":"
    FILESEP="/"
    ;;
  AIX )
    PATHSEP=":"
    FILESEP="/"
    ;;
  CYGWIN* )
    PATHSEP=";"
    FILESEP="/"
    ;;
  Windows* )
    PATHSEP=";"
    FILESEP="\\"
    ;;
  * )
    echo "Unrecognized system!"
    exit 1;
    ;;
esac

UseJcmdPrintMemoryUsage()
{
    pid=$1
    javaLog=$2
    while ! grep -q "For random generator using seed" ${javaLog}
    do
        sleep 0.1  #wait util java main function start finish
    done
    i=0
    rm -rf *-native_memory-summary.log
    while kill -0 ${pid} 2>/dev/null
    do
        ${TESTJAVA}${FS}bin${FS}jcmd ${pid} VM.native_memory summary &> ${i}-native_memory-summary.log
        if [[ 0 -ne $? ]] ; then
            if grep -q "Exception" ${i}-native_memory-summary.log ; then
                #The target java process has been teminated/finished
                #java.io.IOException: No such process
                #com.sun.tools.attach.AttachNotSupportedException: Unable to parse namespace
                #java.io.IOException: Premature EOF
                rm -rf ${i}-native_memory-summary.log
                break
            else
                echo "jcmd command execute fail!"
                exit 1
            fi
        fi
        let i++
        sleep 2
    done
}

set -x
commonJvmOptions="-Xbootclasspath/a:. -XX:+UnlockDiagnosticVMOptions -XX:+WhiteBoxAPI -XX:-DeoptimizeRandom \
 -XX:CompileCommand=dontinline,compiler.codecache.stress.Helper$TestCase::method -XX:NativeMemoryTracking=summary"

rm -rf java.log
${TESTJAVA}${FS}bin${FS}java ${TESTVMOPTS} ${TESTJAVAOPTS} -XX:+SegmentedCodeCache ${commonJvmOptions} \
 -Dtest.src=${TESTSRC} -cp ${TESTCLASSPATH} compiler.codecache.stress.UnexpectedDeoptimizationTestLoop &> java.log &
pid=$!
ps -ef | grep java | grep UnexpectedDeoptimizationTestLoop &> ps-java.log
UseJcmdPrintMemoryUsage ${pid} java.log 2> jcmd-detail-stderr.log
if grep -q "Unable to open socket file" *-native_memory-summary.log ; then
    echo 'jcmd report error: "-native_memory-summary.log"'
    exit 1
fi
perl ${TESTSRC}/check-native-memory-usage.pl 10 `ls *-native_memory-summary.log | sort -n | xargs`
