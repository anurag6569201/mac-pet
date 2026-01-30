import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "http://127.0.0.1:8000/api"
    
    func checkBackendStatus(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/status/") else {
            print("Invalid URL")
            completion(false, "Invalid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error checking status: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(false, "No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let status = json["status"] as? String {
                    print("Backend status: \(status)")
                    completion(true, status)
                } else {
                    print("Invalid JSON response")
                    completion(false, "Invalid JSON response")
                }
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
        
        task.resume()
    }
}
