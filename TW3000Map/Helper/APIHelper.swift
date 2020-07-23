//
//  APIHelper.swift
//  TW3000Map
//
//  Created by rlbot on 2020/7/18.
//  Copyright © 2020 WL. All rights reserved.
//

import Foundation


struct PostItem: Codable {
    var hsnCd: String?        //縣市代號
    var townCd: String?       //鄉鎮區代號
    var storeCd: String?      //分局代號
    var hsnNm: String?        //縣市名稱
    var townNm: String?       //鄉鎮區名稱
    var storeNm: String?      //分局名稱
    var addr: String?         //門市地址
    var zipCd: String?        //郵遞區號
    var tel: String?          //電話
    var busiTime: String?     //營業時間
    var busiMemo: String?     //營業備註
    var total: String?        //服務存量
    var updateTime: String?   //異動時間
    var latitude: String?     //緯度
    var longitude: String?    //經度
}


class APIHelper {
    
    static let apiURLString = "https://3000.gov.tw/hpgapi-openmap/api/getPostData"
    
    
    // MARK: - Fetch Data
    
    class func fetchData(callback: @escaping (Array<PostItem>?) -> Void) {
        httpGET_withFetchPostItems(URLString: apiURLString, callback: callback)
    }
    
    
    // MARK: - HTTP GET
    
    class func httpGET_withFetchPostItems(URLString: String, callback: @escaping (Array<PostItem>?) -> Void) {
        httpRequestWithFetchJsonArray(httpMethod: "GET", URLString: URLString, parameters: nil, callback: callback)
    }
    
    
    // MARK: - HTTP Request with Method
    
    class func httpRequestWithFetchJsonArray(httpMethod: String,
                                             URLString: String,
                                             parameters: Dictionary<String, Any>?,
                                             callback: @escaping (Array<PostItem>?) -> Void)
    {
        // Create request
        let url = URL(string: URLString)!
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        
        // Header
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        // Body
        if let parameterDict = parameters {
            // parameter dict to json data
            let jsonData = try? JSONSerialization.data(withJSONObject: parameterDict)
            // insert json data to the request
            request.httpBody = jsonData
        }
        
        // Task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print(error?.localizedDescription ?? "No data")
                    callback(nil)
                    return
                }
                
                do {
                    let json = try JSONDecoder().decode([PostItem].self, from: data)
                    callback(json)
                } catch {
                    callback(nil)
                }
            }
        }
        task.resume()
    }
    
}

