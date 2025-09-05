# Internet search implementation with web scraping

function __extract_main_content
    set -l html $argv[1]
    # Try to extract main content from HTML
    # Look for common content containers
    set -l content ""
    
    # Try article tags first
    set -l article_content (echo "$html" | string match -r '<article[^>]*>(.*?)</article>' | string replace -r '.*<article[^>]*>(.*?)</article>.*' '$1')
    if test -n "$article_content"
        set content $article_content
    else
        # Try main tag
        set -l main_content (echo "$html" | string match -r '<main[^>]*>(.*?)</main>' | string replace -r '.*<main[^>]*>(.*?)</main>.*' '$1')
        if test -n "$main_content"
            set content $main_content
        else
            # Try content divs
            set -l div_content (echo "$html" | string match -r '<div[^>]*class="[^"]*content[^"]*"[^>]*>(.*?)</div>' | string replace -r '.*<div[^>]*>(.*?)</div>.*' '$1')
            if test -n "$div_content"
                set content $div_content
            end
        end
    end
    
    if test -n "$content"
        # Clean up HTML tags and get text
        set content (echo "$content" | string replace -r '<[^>]*>' '' | string replace -r '\s+' ' ' | string trim)
        # Limit length to avoid overwhelming the AI
        echo "$content" | head -c 2000
    end
end

function __scrape_url
    set -l url $argv[1]
    echo "Fetching: $url"
    
    set -l html (curl -s --max-time 15 -L \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.5" \
        "$url" 2>/dev/null)
    
    if test $status -eq 0 -a -n "$html"
        # Extract title
        set -l title (echo "$html" | string match -r '<title[^>]*>([^<]+)</title>' | string replace -r '.*<title[^>]*>([^<]+)</title>.*' '$1')
        
        # Extract main content
        set -l content (__extract_main_content "$html")
        
        if test -n "$title" -o -n "$content"
            echo "Title: $title"
            echo "Content: $content"
            echo "Source: $url"
            echo "---"
        end
    end
end

function ai_search
    if test (count $argv) -lt 1
        echo "Usage: ai search \"your query\""
        return 1
    end
    set -l query (string join " " -- $argv)
    
    # Check for required tools
    if not command -q curl
        echo "Error: curl is required for web search"
        return 1
    end
    
    echo "Searching for: $query"
    set -l all_results ""
    
    # 1. Get Wikipedia summary (reliable baseline)
    echo "Searching Wikipedia..."
    set -l wiki_url "https://en.wikipedia.org/api/rest_v1/page/summary/"(string escape --style=url "$query")
    set -l wiki_data (curl -s --max-time 10 "$wiki_url" 2>/dev/null)
    
    if test $status -eq 0 -a -n "$wiki_data"
        if command -q jq
            set -l title (echo "$wiki_data" | jq -r '.title // empty' 2>/dev/null)
            set -l extract (echo "$wiki_data" | jq -r '.extract // empty' 2>/dev/null)
            set -l wiki_page_url (echo "$wiki_data" | jq -r '.content_urls.desktop.page // empty' 2>/dev/null)
            
            if test -n "$title" -a -n "$extract"
                set all_results "$all_results\n\n=== Wikipedia ===\nTitle: $title\nSummary: $extract\nSource: $wiki_page_url\n"
                echo "✓ Found Wikipedia article: $title"
            end
        end
    end
    
    # 2. Try DuckDuckGo for instant answers and get actual search results
    echo "Searching DuckDuckGo..."
    set -l ddg_html_url "https://html.duckduckgo.com/html/?q="(string escape --style=url "$query")
    set -l ddg_html (curl -s --max-time 10 \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        "$ddg_html_url" 2>/dev/null)
    
    if test $status -eq 0 -a -n "$ddg_html"
        # Extract search result URLs and titles
        set -l result_urls (echo "$ddg_html" | string match -ar 'uddg=([^"&]+)' | string replace 'uddg=' '' | string unescape --style=url | head -3)
        set -l result_titles (echo "$ddg_html" | string match -ar 'class="result__title"[^>]*><a[^>]*>([^<]+)' | string replace -r '.*>([^<]+)' '$1' | head -3)
        
        if test -n "$result_urls"
            echo "✓ Found "(count $result_urls)" search results"
            set all_results "$all_results\n\n=== Web Search Results ===\n"
            
            # Scrape top results
            set -l i 1
            for url in $result_urls
                if test $i -le 2  # Limit to top 2 to avoid being too slow
                    set -l title_for_url ""
                    if test (count $result_titles) -ge $i
                        set title_for_url $result_titles[$i]
                    end
                    
                    echo "Scraping result $i: $title_for_url"
                    set -l scraped_content (__scrape_url "$url")
                    if test -n "$scraped_content"
                        set all_results "$all_results\n$scraped_content\n"
                    end
                end
                set i (math $i + 1)
            end
        end
    end
    
    # 3. Try to get recent news from RSS feeds if query seems news-related
    if string match -qr "news|current|latest|recent|today|2024|2025" "$query"
        echo "Searching recent news..."
        
        # Try a few news RSS feeds
        set -l news_sources \
            "https://rss.cnn.com/rss/edition.rss" \
            "https://feeds.bbci.co.uk/news/rss.xml" \
            "https://rss.reuters.com/news/world"
        
        for feed_url in $news_sources
            set -l rss_content (curl -s --max-time 8 "$feed_url" 2>/dev/null)
            if test $status -eq 0 -a -n "$rss_content"
                # Extract recent headlines that might match our query
                set -l headlines (echo "$rss_content" | string match -ar '<title><!\[CDATA\[([^\]]+)\]\]></title>' | string replace -r '.*\[CDATA\[([^\]]+)\]\].*' '$1' | head -5)
                if test -z "$headlines"
                    set headlines (echo "$rss_content" | string match -ar '<title>([^<]+)</title>' | string replace -r '.*<title>([^<]+)</title>.*' '$1' | head -5)
                end
                
                # Filter headlines that might be relevant
                set -l relevant_headlines ""
                for headline in $headlines
                    if string match -qi "*"(string split " " "$query")[1]"*" "$headline"
                        set relevant_headlines "$relevant_headlines\n- $headline"
                    end
                end
                
                if test -n "$relevant_headlines"
                    set all_results "$all_results\n\n=== Recent News Headlines ===\n$relevant_headlines\n"
                    echo "✓ Found relevant news headlines"
                    break
                end
            end
        end
    end
    
    # 4. If still no good results, try one more approach
    if test -z "$all_results"
        echo "No results found with initial search. Trying alternative sources..."
        
        # Try searching specific high-quality sites
        for site in "site:stackoverflow.com" "site:github.com" "site:reddit.com"
            set -l site_query "$query $site"
            set -l ddg_site_url "https://html.duckduckgo.com/html/?q="(string escape --style=url "$site_query")
            set -l site_html (curl -s --max-time 8 \
                -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
                "$ddg_site_url" 2>/dev/null)
            
            if test $status -eq 0 -a -n "$site_html"
                set -l site_urls (echo "$site_html" | string match -ar 'uddg=([^"&]+)' | string replace 'uddg=' '' | string unescape --style=url | head -1)
                if test -n "$site_urls"
                    echo "Found result on "(string replace 'site:' '' "$site")
                    set -l scraped_content (__scrape_url "$site_urls[1]")
                    if test -n "$scraped_content"
                        set all_results "$all_results\n\n=== Alternative Source ===\n$scraped_content\n"
                        break
                    end
                end
            end
        end
    end
    
    # Prepare response
    if test -z "$all_results"
        echo "Could not find specific web information. Using general knowledge..."
        set -l ai_prompt "The user is asking about: \"$query\"\n\nI wasn't able to retrieve current web information for this query. Please provide a helpful response based on your training knowledge. If this requires very recent information, mention that the user might need to search the web directly for the most current details.\n\nQuery: $query"
        
        set -l rules_file $HOME/.config/ai/rules.txt
        set -l combined $ai_prompt
        if test -f $rules_file
            set -l raw_rules (cat $rules_file)
            if test (count $raw_rules) -gt 0
                set -l rules_text (string join "\n" -- $raw_rules)
                set combined (printf "%s\n\n%s" "Rules:\n$rules_text" "$ai_prompt")
            end
        end
        
        printf "\n\nai response (general knowledge):\n"
        ollama run $MODEL "$combined"
    else
        echo "Compiling search results for AI analysis..."
        set -l ai_prompt "Based on these comprehensive search results, please answer the query: \"$query\"\n\nSearch Results:$all_results\n\nPlease provide a detailed and helpful answer based on the information above. Cite sources when relevant and mention if any information might need verification for currency."
        
        set -l rules_file $HOME/.config/ai/rules.txt
        set -l combined $ai_prompt
        if test -f $rules_file
            set -l raw_rules (cat $rules_file)
            if test (count $raw_rules) -gt 0
                set -l rules_text (string join "\n" -- $raw_rules)
                set combined (printf "%s\n\n%s" "Rules:\n$rules_text" "$ai_prompt")
            end
        end
        
        printf "\n\nai response (with web search):\n"
        ollama run $MODEL "$combined"
    end
end