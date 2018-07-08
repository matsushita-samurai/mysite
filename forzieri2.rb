# URLにアクセスするためのライブラリの読み込み
require 'open-uri'
# Nokogiriライブラリの読み込み
require 'nokogiri'

require 'bundler'
# require 'bundler/setup'
require 'capybara/poltergeist'
Bundler.require

u = 1 # urlのiの部分
j = 1 # 商品累積番号
check = true # URLのループの条件に使う

begin

  if u < 2 then
    url = 'https://www.jp.forzieri.com/jpn/deptd.asp?l=jpn&c=jpn&dept_id=18'
  else
    url = "https://www.jp.forzieri.com/jpn/deptd.asp?l=jpn&c=jpn&dept_id=18&page=" + u.to_s
  end

  charset = nil
  html = open(url) do |f|
    charset = f.charset # 文字種別を取得
    f.read # htmlを読み込んで変数htmlに渡す
  end
  # htmlをパース(解析)してオブジェクトを生成
  doc = Nokogiri::HTML.parse(html, nil, charset)

  article = doc.css('article')
  # ループ抜けの条件
  if article.empty?
    check = false
    break
  end


  productlists = []

      # 本来1..48(1ページに最大48商品)だが開発中なので1..2商品にしている
      (1..48).each do |n|
        each_bag = []
        # 48商品ない場合はエラーになるので例外処理
        begin
          # 1商品ごとの商品詳細ページのURLを取得
          de_url = doc.css("#product_list_item_#{n.to_s} > div.pl-image-wrapper > a").attr('href').value
        rescue => error
          break
        end #begin 例外処理


        Capybara.register_driver :poltergeist do |app|
          #Capybara::Poltergeist::Driver.new(app, {js_errors: false, timeout: 1000, phantomjs_options: [&quot;--load-images=no&quot;] })
          Capybara::Poltergeist::Driver.new(app, {js_errors: false,timeout: 1000, phantomjs_options: ['--debug=no', '--load-images=no', '--ignore-ssl-errors=yes', '--ssl-protocol=TLSv1'], :debug => false})
        end
        session = Capybara::Session.new(:poltergeist)
        #上記で取得した商品詳細のurlにvisit
        session.visit de_url

        # Sold Outの場合は次の繰り返しへ
        soldoutcheck= Nokogiri::HTML.parse(session.source).css('#variantInfo > p').text
        if soldoutcheck == "Sold Out"
          next
        end

        # 商品累積番号セット
        each_bag.push(j)
        # 商品skuを取得
        sku = session.find('#productSku').text
        each_bag.push(sku)

        # ブランド名を取得
        brand = session.find('#productInfo > div > div.product-title > h1 > span.brand-name > a').text
        each_bag.push(brand)

        # 商品名を取得
        name = session.find('#productInfo > div > div.product-title > h1 > span.product-name').text
        each_bag.push(name)


        # プライスを取得
        sale_price = session.find('#salePrice').text
        price = sale_price.delete("¥").delete(",").to_i + 1500
        if sale_price.empty?
          list_price = session.find('#listPrice').text.delete("¥").delete(",").to_i
          discount = Nokogiri::HTML.parse(session.source).css('#bollinoPlaceholder > div > div > div.bollino-front > div > span.msg-percentageoff').text
          discount_rate = discount.delete("%").delete("Off").delete(" ").to_i
          price = list_price * (1 - discount_rate / 100.0) + 1500
        elsif sale_price.nil? && discount_rate.nil?
          price = session.find('#listPrice').text.delete("¥").delete(",").to_i +1500
        end

        each_bag.push(price)




        # 製品詳細をクリックする => onClickが実行される
        session.find('a#trigger_scheda_tecnica').trigger('click')
        # 商品詳細テキストを取得
        prod_desc_arr = []
        (1..6).each do |i|
          begin
            key = session.find(:css, "#schedaTecnica > table:nth-child(2) > tbody > tr:nth-child(#{i}) > th").text
            value = session.find(:css, "#schedaTecnica > table:nth-child(2) > tbody > tr:nth-child(#{i}) > td").text
          rescue => error
            key = "サイズ"
            value = "free"
          end #begin 例外処理



          prod = []
          prod.push(key,value)
          prod_desc_arr.push(prod)
        end

        detail = prod_desc_arr
        each_bag.push(detail)

        # 画像を取得
        pics = Nokogiri::HTML.parse(session.source).css('img.product-image')
        pics.each do |picture|
          picture = picture.attr('src')
          each_bag.push(picture)
        end

        each_bag.each do |info|
          puts info
        end


        # product_list配列にeach_bag配列を格納し、多次元配列にする
        productlists.push(each_bag)


        j += 1

      end # (1..48)each
  u += 1

end while check == true # begin while loop
