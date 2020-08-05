$CONST_CURRENT_URL = "https://www.splunk.com/en_us/download/universal-forwarder.html"
$CONST_LEGACY_URL = "https://www.splunk.com/en_us/download/previous-releases/universalforwarder.html"

$CONST_MENU = @(
    "Download latest Version",
    "Download Specific Version",
    "Download Specific Package",
    "Download All - Note: This will take a long time!"
)

function Get-SplunkUFurls($url){
    $response = Invoke-RestMethod $url 
    $urls = $response | select-string -pattern  'data-link="(?<url>https://[^"]+)' -AllMatches | ForEach-Object {$_.matches.groups | Where-Object Name -eq 'url'} | Select-Object -ExpandProperty Value
    $urls | Select-String -Pattern "https:\/\/.+(?=releases)releases\/(?<version>[^\/]+)\/(?<os>[^\/]+)\/(?<file_name>[^\/]+)" -AllMatches | ForEach-Object {
        @{
            'url' = $_;
            'version' = $_.Matches.groups[1].value;
            'os' = $_.Matches.groups[2].value;
            'file_name' = $_.Matches.groups[3].value
        }
    }
}

function Get-SplunkUFBinaries($url_list){
    foreach ($hashtable_url in $url_list){
        $out_file = "$($hashtable_url.version)/$($hashtable_url.os)/$($hashtable_url.file_name)"
        New-Item -Path $out_file -Force | Out-Null
        (New-Object System.Net.WebClient).DownloadFile($hashtable_url.url.ToString(), $out_file)
        Write-Host  "WRITING FILE: $out_file"
    }    
}

function Write-Host-Options($options){
    ForEach ($opt in $options){
        Write-Host "[$($options.IndexOf($opt) + 1)] - $opt" 
    }
    do{
        try{
            [ValidatePattern('^\d+$')]$selection = Read-Host "Please select an option"
            if ($selection -gt 0 -and $selection -lt ($options.Length + 1)){
                return $options[$selection - 1]
            }
            else{
                throw "Invalid Selection"
            }
        }
        catch{
            #TODO
        }
    }
    until($?)
}

function Select-SplunkList($filters){

}


function main(){
    $menu_selection = Write-Host-Options($CONST_MENU)
    
    $current_splunk_list = Get-SplunkUFurls($CONST_CURRENT_URL)
    $all_splunk_list = Get-SplunkUFurls($CONST_LEGACY_URL) + $current_splunk_list
    
    switch($CONST_MENU.IndexOf($menu_selection) + 1){
        1{
            $get_output = $current_splunk_list
        }
        2{
            $version = Write-Host-Options(($all_splunk_list).version | Sort-Object -Unique -Descending)
            $get_output = $all_splunk_list | Where-Object {$_.version -eq $version}        
        }
        3{
            $os = Write-Host-Options($all_splunk_list.os | Sort-Object -Unique -Descending) 
            $version = Write-Host-Options(($all_splunk_list | Where-Object os -eq $os).version | Sort-Object -Unique -Descending)
            $package = Write-Host-Options(($all_splunk_list | Where-Object {($_.os -eq $os) -and ($_.version -eq $version)}).file_name | Sort-Object -Unique -Descending)
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
