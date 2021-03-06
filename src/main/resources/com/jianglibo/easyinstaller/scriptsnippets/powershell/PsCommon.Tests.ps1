﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "PsCommon" {
    It "does something useful" {
        $true | Should Be $true
    }
    It "should handle out context" {
        $twoReached = $False
        (1,2,3 | ForEach-Object {if ($_ -gt 1) {$twoReached = $True; $_}} | ForEach-Object {if ($twoReached) {$_}}).Count | Should Be 2
    }
    It "scriptmethod parameters" {
        $oo = New-Object -TypeName PSObject
        $oo | Add-Member -MemberType ScriptMethod -Name appp -Value {
             Param([String]$fileToWrite)
             $fileToWrite
        }
        $oo.appp("abaac") | Should Be "abaac" 
    }
    It "should addKv commentKv work" {
        $kvf = New-SectionKvFile -FilePath (Join-Path $here -ChildPath "fixtures\NetworkManager.conf")
        $ht = [HashTable]$kvf.blockHt;

        $kvf.blockHt.Count | Should Be 2

        $kvf.blockHt["[main]"] -contains "plugins=ifcfg-rh" | Should Be $True

        $kvf.addKv("a", 1, "[main]")
        $kvf.blockHt["[main]"] -contains "a=1" | Should Be $True

        $kvf.blockHt["[main]"].Count | Should Be 3
        $kvf.addKv("a", 1, "[main]")
        $kvf.blockHt["[main]"].Count | Should Be 3

        $kvf.commentKv("x", "[main]")
        $kvf.blockHt["[main]"].Count | Should Be 3

        $kvf.commentKv("a", "[main]")
        $kvf.blockHt["[main]"] -contains "a=1" | Should Be $False
        $kvf.blockHt["[main]"] -contains "#a=1" | Should Be $True

        $kvf.addKv("a", 2, "[main]")
        $kvf.blockHt["[main]"] -contains "a=1" | Should Be $False
        $kvf.blockHt["[main]"] -contains "#a=1" | Should Be $False
        $kvf.blockHt["[main]"] -contains "a=2" | Should Be $True
        $kvf.blockHt["[main]"].Count | Should Be 3


    }
    It "should write to file work" {
        $kvf = New-SectionKvFile -FilePath (Join-Path $here -ChildPath "fixtures\NetworkManager.conf")
        $ht = [HashTable]$kvf.blockHt;
        $ht.Keys | Should Be @("[main]", "[logging]")

        ([Array]$kvf.prefix).Count| Should Be 12

        $tmpf = (New-TemporaryFile).ToString()

        $kvf.writeToFile($tmpf)

        $line2 = Get-Content $tmpf | Select-Object -First 2

        $line2 | Should Be @("# Configuration file for NetworkManager.", "#")
        Remove-Item -Path $tmpf
    }

    It "should handle ip addr" {
        $ipaddrout = Join-Path -Path $here -ChildPath "fixtures\ipaddr.txt"
        (Get-Content $ipaddrout | ForEach-Object -Begin {$curg = $null} -Process {
            if($_ -match "^\d+:\s*(\w+):") {
                $curg = $Matches[1]
            }
            @{gp=$curg;value=$_}
        } -End {$ht} | Group-Object -AsHashTable -AsString -Property {$_["gp"]}).Count | Should Be 3
    }

    It "can handle kvFile" {
        $cf = Join-Path -Path $here -ChildPath "fixtures\dnsmasq.conf"
        $kvf = New-KvFile -FilePath $cf
        Test-Path $cf | Should Be $True
        ($kvf.lines).count | Should Be 666

        $kvf.addKv("a", "b")
        ($kvf.lines).count | Should Be 667

        $kvf.commentKv("a");
        ($kvf.lines).count | Should Be 667

        ($kvf.lines | Where-Object {$_ -eq "#a=b"}).count | Should Be 1
    }

    It "Should handle select object" {
        1,2,3 | Select-Object @{N="k";E={$_ + 1}} | Select-Object -ExpandProperty k | Write-Output -NoEnumerate | Should Be @(2,3,4)
    }

    It "should handle addHost" {
        $fixture = Join-Path -Path $here -ChildPath "fixtures\hosts"
        $hf = New-HostsFile -FilePath $fixture
        $hf.FilePath -cmatch "hosts$" | Should Be $True
        $hf.lines.count | Should Be 2

        $hf.addHost("192.168.33.10", "hello.cc")
        $hf.lines.count | Should Be 3
        $hf.addHost("192.168.33.10", "hello.cc")
        $hf.lines.count | Should Be 3

        $hf.lines | Select-String -Pattern "\s+hello.cc" | Write-Output -NoEnumerate | Should Be @("192.168.33.10 hello.cc")

        $hf.addHost("192.168.33.10", "hello.dd")
        $hf.lines | Select-String -Pattern "\s+hello.cc" | Write-Output -NoEnumerate | Should Be @("192.168.33.10 hello.cc hello.dd")

        $hf.addHost("192.168.33.10", "hello.dd").addHost("192.168.33.10", "hello.dd").addHost("192.168.33.10", "hello.dd")
        $hf.lines | Select-String -Pattern "\s+hello.cc" | Write-Output -NoEnumerate | Should Be @("192.168.33.10 hello.cc hello.dd")
    }

    It "should handle varagrs" {
        function t-f {
            Param($ports)
            if ($ports -is [String]) {
                $ports = $ports -split "[^\d]+"
            }
            $ports -join ","
        }

        t-f "1,2,3" | Should Be "1,2,3"
        t-f 1,2,3 | Should Be "1,2,3"
        t-f "1.2.3" | Should Be "1,2,3"
    }

    It "should handle envforexec" {
        $fixture = Join-Path -Path $here -ChildPath "fixtures/envforcodeexec.json"
        $efe = New-EnvForExec $fixture

        $efe.getType().Name | Should  Be "pscustomobject"

        $efe.remoteFolder | Should  Be "/opt/easyinstaller"

        $p1 = $efe.remoteFolder | Join-Path -ChildPath "zookeeper-3.4.9.tar.gz"

        $efe.getUploadedFile() | Should Be $p1

        [Boolean]$efe.getUploadedFile("akb") | Should Be $False

        $p1 = $efe.remoteFolder | Join-Path -ChildPath "zookeeper-3.4.9.tar.gz"
        [Boolean]$efe.getUploadedFile("akb") | Should Be $False

        $efe.software.configContent | Should Be $True

        $efe.software.configContent.zkports | Should Be "2888,3888"

        $kvary = ([HashTable]$efe.software.configContent.asHt("zkconfig")).GetEnumerator() | ForEach-Object {"{0}={1}" -f $_.Key, $_.Value}

        $kvary -contains "initLimit=5" | Should Be $True

        $efe.software.fullName | Should Be "zookeeper-CentOs7-3.4.9"

        $efe.resultFolder -replace "\\","/" | Should Be "/opt/easyinstaller/results/zookeeper-CentOs7-3.4.9"

        Test-Path $efe.resultFolder  -PathType Container | Should Be $True
        
    }

    It "should inert a line" {
        $tmp = New-TemporaryFile

        Set-Content -Path $tmp -Value 'a', 'ZOOBINDIR="${ZOOBINDIR:-/usr/bin}"', 'b', 'c'

        (Get-Content $tmp).Count | Should Be 4

        Insert-Lines $tmp "^ZOOBINDIR=" "hello"
        $c = Get-Content $tmp
        $c[1] | Should Be "hello"
        $c.Count | Should Be 5

        Test-Path ($tmp.FullName + ".origin") -PathType Leaf | Should Be $True

        Set-Content -Path $tmp -Value 'a', 'ZOOBINDIR="${ZOOBINDIR:-/usr/bin}"', 'b', 'c'
        Insert-Lines -FilePath $tmp "^ZOOBINDIR=" -lines "hello","1","2" -after
        $c = Get-Content $tmp
        $c[2] | Should Be "hello"
        $c.Count | Should Be 7

        Remove-Item $tmp
    }

    It "about replace" {
        "abc" -replace "a","b" | Should Be "bbc"
        "0ab1c2" -replace "[a-z]+","b" | Should Be "0b1b2"
    }

    It "should by reference" {
        function t-t {
            Param($ht)
            $ht.newkey = "123"
        }

        $outht = @{x=5}
        t-t $outht

        $outht.newkey | Should Be "123"
    }

    It "should Out-File work" {
        $t = New-TemporaryFile
        @(1,2,3) | Out-File -FilePath $t
        Get-Content $t | Write-Output -NoEnumerate | Should Be @(1,2,3)
    }

    It "is more about function" {
        function Get-Pipeline { 
          process {"The value is: $_"} 
        }
        1,2 | Get-Pipeline |Write-Output -NoEnumerate| Should Be @("The value is: 1", "The value is: 2")

        function Get-PipelineBeginEnd {
          begin {"Begin: The input is $input"}
          end {"End:   The input is $input" }
       }

       1,2 | Get-PipelineBeginEnd | Write-Output -NoEnumerate | Should Be @("Begin: The input is ","End:   The input is 1 2")
    }

    It "is a random password gen" {
        $r = New-RandomPassword
        $r.length | Should Be 8

        $r = New-RandomPassword 12
        $r.length | Should Be 12

        $r = New-RandomPassword -Count 13
        $r.length | Should Be 13

        $r = 15 | New-RandomPassword
        $r.length | Should Be 15
    }

    It "should handle remain args" {
        function t-t {
            Param([int]$i, [string]$s, [parameter(ValueFromRemainingArguments)]$others)
            $others
        }

        (t-t 1 "s" 1 2 3 4).length | Should Be 4
        (t-t 1 "s" 1 2 3 4).getType() | Should Be "System.Object[]"
        (t-t 1 "s" 1,2,3,4).length | Should Be 4
        (t-t 1 "s" 1,2,3,4).getType() | Should Be "System.Object[]"
    }

    It "handle new-runner" {
        New-Runner "bash" -envfile "/abcc" | Should Be 'bash /abcc -envfile /abcc -action $1'
        New-Runner "powershell -File {code} -envfile {envfile} -action {action}" -envfile "/abcc.Ps1.env" | Should Be 'powershell -File /abcc.Ps1 -envfile /abcc.Ps1.env -action $1'

        New-Runner "bash" -envfile "/abcc" -code "/abcccode" | Should Be 'bash /abcccode -envfile /abcc -action $1'
        New-Runner "powershell -File {code} -envfile {envfile} -action {action}" -envfile "/abcc.Ps1.env" -code "/abcccode.Ps1" | Should Be 'powershell -File /abcccode.Ps1 -envfile /abcc.Ps1.env -action $1'

    }
}
