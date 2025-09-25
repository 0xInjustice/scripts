#!/bin/bash

echo "Enter domain name:"
read domain

# Create a directory for the domain
mkdir -p $domain
cd $domain || exit 1  # Exit if directory change fails

# Function to find subdomains
subdomain() {
    echo "----Finding subdomains----"
    subfinder -d $domain -all -recursive -o subfinder.txt &
    assetfinder --subs-only $domain > assetfinder.txt &
    findomain -t $domain | tee findomain.txt &
    wait
    echo "----merging all subdomains----"
    cat subfinder.txt assetfinder.txt findomain.txt | sort -u > subdomains.txt
    rm subfinder.txt assetfinder.txt findomain.txt
    echo "----discover alive subdomains----"
    cat subdomains.txt | httpx -ports 80,443,8080,8000,8888 -threads 200 -timeout 5 -retries 3 > livesubdomains.txt
}

# Function for detecting vulnerabilities using GF patterns
gf_patterns() {
    gf_list=("lfi" "sqli" "ssrf" "xss")
    for pattern in "${gf_list[@]}"; do
        cat totalurls.txt | gf $pattern > gf_$pattern.txt
    done
}

# URL Collection and Analysis
url_collection_analysis() {
    timeout 60s katana -u livesubdomains.txt -d 2 -o urls.txt &
    timeout 60s gau --mc 200 $domain | urldedupe >> urls.txt &
    wait
    cat urls.txt | hakrawler -u >> urls2.txt &
    urlfinder -d $domain | sort -u >> urls2.txt 
    wait
    cat urls* | sort -u > allurls.txt
    rm urls.txt urls2.txt
    cat allurls.txt | grep -E ".php|.asp|.aspx|.jspx|.jsp" | grep '=' | sort > output.txt
    cat output.txt | sed 's/=.*/=/' >> out.txt 
    cat allurls.txt | grep -E '\?[^=]+=.+$' >> out.txt 
    cat allurls.txt | grep '=' | urldedupe >> out.txt 
    wait
    cat *.txt | sort -u > totalurls.txt
}

# Start functions
subdomain
url_collection_analysis
gf_patterns

echo "All tasks completed for domain: $domain"

