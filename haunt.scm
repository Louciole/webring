(use-modules
 (ice-9 textual-ports)
 (ice-9 streams)
 (json)
 (haunt asset)
 (haunt site)
 (haunt html)
 (haunt page)
 (haunt reader)
 (haunt builder assets)
 (haunt builder blog)
 (haunt builder atom)
 (haunt reader commonmark)
 (srfi srfi-1)
 (srfi srfi-19)
 (webring))

(define (simple-icon name)
  `(img (@
		 (height 16)
		 (width 16)
		 (src ,(string-append "https://cdn.simpleicons.org/" name)))))

(define tor-icon
  (simple-icon "torproject"))

(define ipfs-icon
  (simple-icon "ipfs"))

(define i2p-icon
  `(img (@
		 (height 16)
		 (width 16)
		 (src "https://upload.wikimedia.org/wikipedia/commons/8/84/Itoopie.svg"))))

(define* (stylesheet url)
  `(link (@ (rel "stylesheet")
			(href ,url))))

(define* (page-template site body #:key title)
  `((doctype "html")
	(html (@ (lang "en"))
		  (head
		   (meta (@ (charset "utf-8")))
		   (meta (@ (http-equiv "Content-Language") (content "en")))
		   (meta (@ (name "viewport") (content "width=device-width")))
		   ,(stylesheet "https://unpkg.com/normalize.css@8.0.1/normalize.css")
		   ,(stylesheet "/assets/css/style.css")
		   (title ,(if title
					   (string-append title " -- DevSE")
					   (site-title site)))
		   (link (@ (rel "shortcut icon")
					(href "/favicon.ico"))))
		  (body
		   (div (@
				 (class "page")
				 (role "main"))
				,body
				(div (@
					  (id "devse-webring")
					  (role "nav")))
				(script (@ (src "/assets/js/config.js")))
				(script (@ (src "/assets/js/webring-index.js")))
				(script (@ (src "/assets/js/webring-widget.js"))))))))

(define (http-entry name http)
  (let* ((clearnet (assoc-ref http 'clearnet))
		 (onion (assoc-ref http 'onion))
		 (i2p (assoc-ref http 'i2p)))
	`((a (@ (href ,clearnet) (target "_blank")) ,name)
		 ,(if onion
			  `(a (@ (href ,onion) (target "_blank")) ,tor-icon)
			  '())
		 ,(if i2p
			  `(a (@ (href ,i2p) (target "_blank")) ,i2p-icon)
			  '()))))
 
(define (assets-entry name assets)
  (let ((80x15 (assoc-ref assets '80x15))
		(88x31 (assoc-ref assets '88x31)))
	`((td
	   ,(if 80x15
			`(img (@
				   (src ,(string-append "/assets/80x15/" 80x15))
				   (alt ,(string-append name " button"))))
			'()))
	  (td
	   ,(if 88x31
			`(img (@
				   (src ,(string-append "/assets/88x31/" 88x31))
				   (alt ,(string-append name " banner"))))
			'())))))

(define (site-entry entry)
  (let* ((name (assoc-ref entry 'name))
		 (description (assoc-ref entry 'description))
		 (assets (assoc-ref entry 'assets))
		 (protocols (assoc-ref entry 'protocols))
		 (http (assoc-ref protocols 'http))
		 (ipfs (assoc-ref protocols 'ipfs)))
  `(tr
	(td ,(http-entry name http)
		,(if ipfs
			 `(a (@ (href ,ipfs) (target "_blank")) ,ipfs-icon)
			 '()))
	(td ,description)
	,(assets-entry name assets))))

(define last-update
  `(p ,(format #f "Last update: ~a" (date->string (current-date) "~4"))))

(define site-table
  `(table
	(thead (tr
			(th (@ (rowspan "2")) "Name")
			(th (@ (rowspan "2")) "Description")
			(th (@ (colspan "2")) "Images"))
		   (tr
			(th "80x15")
			(th "88x31")))
	(tbody
	 ,@(map site-entry (array->list site-list)))))

(define (raw-script-entry url)
  (format #f "<script src=~s />~%" url))

(define site-raw-widget
  `((h2 (@ (id "widget")) "Widget")
	(pre (code
		  ,(format #f "<div id=~s ></div>~%~%" "devse-webring")
		  ,(raw-script-entry "/assets/js/webring-index.js")
		  ,(raw-script-entry "/assets/js/webring-widget.js")))))

(define (index-page site posts)
  (make-page
   "index.html"
   (page-template site
				  `((h1 "DevSE webring directory")
					,last-update
					(p "You can download " (a (@ (href "/webring.json")) "raw data (in json)") " and adapt it to your web/gopher site, or include our " (a (@ (href "#widget")) "tiny widget") " that you can customize using css")
					(p "If you want to join us, please read " (a (@ (href "/docs/how-to-join.html")) "this guide"))
					,site-table
					,site-raw-widget))
   sxml->html))

(define (page->sxml site template path)
  (define reader
	(or (find (lambda (reader)
				(reader-match? reader path))
			  (site-readers site))
		(error "No reader found for file:" path)))
  (define-values (file-metadata file-sxml)
	((reader-proc reader) path))
  (template site file-sxml #:title (assoc-ref file-metadata 'title)))

(define (docs-join-page site posts)
  (make-page
   "docs/how-to-join.html"
   (page->sxml site page-template "docs/how_to_join.md")
   sxml->html))

(define (docs-coc-page site posts)
  (make-page
   "docs/code-of-conduct.html"
   (page->sxml site page-template "docs/CODE_OF_CONDUCT.md")
   sxml->html))

(define (404-page site posts)
  (make-page
   "404.html"
   (page-template site
				  `((h1 "404 - Eww ! You are not supposed to be here.")
					(figure
							(img (@
								  (class "eww")
								  (src "/assets/devsechan/eww.png")
								  (alt "DevSE-chan eww")))
							(figcaption (small "(c) Meaxy Kusama")))))
   sxml->html))

(define (webring-json-page site posts)
  (make-page
   "webring.json"
   site-list
   scm->json))

(define (webring-index-js site posts)
  (make-page
   "/assets/js/webring-index.js"
   (format #f "const devse_webring_list = ~a;" (scm->json-string site-list))
   display))

(site #:title "DevSE webring directory"
	  #:domain "//webring.devse.wiki"
	  #:default-metadata '(
						   (author . "DevSE contributors"))
      #:readers (list commonmark-reader)
	  #:builders (list
				  index-page
				  docs-join-page
				  docs-coc-page
				  404-page
				  webring-json-page
				  webring-index-js
				  (static-directory "assets")))
