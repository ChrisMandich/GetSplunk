$CONST_CURRENT_URL = "https://www.splunk.com/en_us/download/universal-forwarder.html"
$CONST_LEGACY_URL = "https://www.splunk.com/en_us/download/previous-releases/universalforwarder.html"

$CONST_MENU = @(
    "Download latest Version",
    "Download Specific Version",
    "Download Specific Package",
    "Download All - Note: This will take a long time!"
)

function Get-SplunkUFurls($url){
<#
    .SYNOPSIS
        Gets Splunk Universal Forwarder URL and returns available packages.

    .DESCRIPTION
        Gets Splunk Universal Forwarder URL and returns available packages based on a regular expression and contents found in "data-link".
        The data collected includes: url, version, os, and file_name.
        This data is stored in an array of hashtables. 

    .INPUTS
        Provide url in String form.

    .OUTPUTS
        Outputs array of hastables. Hashtable includes url, version, os and file_name of each result from Splunk url.
#>
    $response = (New-Object System.Net.WebClient).DownloadString([System.Uri]$url)
    $urls = $response | select-string -pattern  'data-link="(?<url>https://[^"]+)' -AllMatches | ForEach-Object {$_.matches.groups | Where-Object Name -eq 'url'} | Select-Object -ExpandProperty Value
    $urls | Select-String -Pattern "https:\/\/.+(?=releases)releases\/(?<version>[^\/]+)\/(?<os>[^\/]+)\/(?<file_name>[^\/]+)" -AllMatches | ForEach-Object {
        @{
            'url' = $_.tostring();
            'md5_url' = (-join ($_.tostring(),".md5"))
            'version' = $_.Matches.groups[1].value;
            'os' = $_.Matches.groups[2].value;
            'file_name' = $_.Matches.groups[3].value
        }
    }
}

function Test-MD5Hash{
<#
    .SYNOPSIS
        Tests hash of provided file path against provided file hash.

    .DESCRIPTION
        Uses Get-FileHash to return MD5 hash of file_path. 
        Compares the uppercase results of file_path and provided md5hash.
        Return True if the match, False if they do not. 

    .PARAMETER Path
        File Path we are comparing hash to. 
    
    .PARAMETER md5hash
        MD5 hash being compared to Path

    .OUTPUTS
        True - Hashes match / False - Hashes do not match
#>
    param(
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$true)][String]$md5hash
    )
    $file_md5hash = (Get-FileHash -Path $Path -Algorithm "MD5").Hash.ToUpper()
    $check_md5hash = $md5hash.ToUpper()

    if($file_md5hash.Equals($check_md5hash)){
        $result = $true
    }
    else{
        $result = $false
    }
    
    return $result
}

function Get-SplunkUFBinaries($url_list){
<#
    .SYNOPSIS
        Gets Splunk Binary Based on provided list.

    .DESCRIPTION
        Gets Splunk Universal Forwarder Binary provided as an Input.
        Iterates through Arrayof hashtables to output each binary based on provided url, version, os, and file_name.
        Written to disk in the following form: "version/os/file_name"

    .INPUTS
        Provide Array of Hashtables with url, version, os, and file_name.

    .OUTPUTS
        Outputs file to disk based on input provided. Write's output when file download is complete.
#>
    foreach ($hashtable_url in $url_list){
        $out_dir = "$($hashtable_url.version)/$($hashtable_url.os)"
        $url = [System.Uri]$hashtable_url.url
        $md5 = ((New-Object System.Net.WebClient).DownloadString([System.Uri]$hashtable_url.md5_url) | Select-String -Pattern "\=\s([a-fA-Z0-9]{32})$" -AllMatches).Matches.Groups[1].Value
        
        Write-Host "DOWNLOADING: $url"
        New-Item -ItemType Directory -Path $out_dir -Force | Out-Null
        $out_file = Join-Path -Path $(Convert-Path $out_dir) -ChildPath $($hashtable_url.file_name)
        Write-Host "WRITING FILE: $out_file"
        Write-Host "SPLUNK MD5: $md5"
        
        (New-Object System.Net.WebClient).DownloadFile($url, $out_file)

        if (Test-MD5Hash -path $out_file -md5hash $md5){
            Write-Host -ForegroundColor Green "MD5 PASS: $md5"
        }
        else{
            Write-Host -ForegroundColor Red "MD5 FAIL: $md5"
            Write-Host -ForegroundColor Yellow "REMOVING: $out_file"
            Remove-Item -Force $out_file
        }
        
    }    
}

function Write-HostOptions{
<#
    .SYNOPSIS
        Outputs options based on provided Array. Requests for selection from Read-Host, validates range, and outputs result.

    .DESCRIPTION
        Outputs options based on provided Array. Requests for selection from Read-Host, validates range, and outputs result.

    .PARAMETER title
        Provide a title to return

    .PARAMETER options
        Provide Array of options to be output.

    .OUTPUTS
        Outputs result based on user selection.
#>
    param(
        [Parameter(Mandatory=$true)][System.String]$title,
        [Parameter(Mandatory=$true)][System.Array]$options
    )
    Write-Host $title
    ForEach ($opt in $options){
        Write-Host "[$($options.IndexOf($opt) + 1)] - $opt" 
    }
    do{
        try{
            [ValidatePattern('^[0-9]+$')]$selection = Read-Host "Please select an option"
            if ($selection -In 0..$($options.Length + 1)){
                return $options[$selection - 1]
            }
            else{
                throw "Invalid Selection: $selection. Options Length: $($options.Length)"
            }
        }
        catch{
            #TODO
        }
    }
    until($?)
}

function main(){
    $menu_selection = Write-HostOptions -title "Please choose how to proceed." -options $CONST_MENU 
    $all_splunk_list = @()
    $current_splunk_list = @()
    
    Get-SplunkUFurls($CONST_CURRENT_URL) | ForEach-Object {
        $all_splunk_list += $_
        $current_splunk_list += $_
    }

    Get-SplunkUFurls($CONST_LEGACY_URL) | ForEach-Object {
        $all_splunk_list += $_
    }
    
    switch($CONST_MENU.IndexOf($menu_selection) + 1){
        1{
            $get_output = $current_splunk_list
        }
        2{
            $version = Write-HostOptions -title "Select Version" -options $(($all_splunk_list).version | Sort-Object -Unique -Descending)
            $get_output = $all_splunk_list | Where-Object {$_.version -eq $version}        
        }
        3{
            $os = Write-HostOptions -title "Select Operating System" -options $($all_splunk_list.os | Sort-Object -Unique -Descending)
            $version = Write-HostOptions -title "Select Version" -options $(($all_splunk_list | Where-Object os -eq $os).version | Sort-Object -Unique -Descending)
            $package = Write-HostOptions -title "Select Package" -options $(($all_splunk_list | Where-Object {($_.os -eq $os) -and ($_.version -eq $version)}).file_name | Sort-Object -Unique -Descending)
            $get_output = $all_splunk_list | Where-Object {($_.os -eq $os) -and ($_.version -eq $version) -and ($_.file_name -eq $package)}        
        }
        4{
            $get_output = $all_splunk_list
        }
        Default{

        }
    }
    
    Get-SplunkUFBinaries($get_output)
}

main
