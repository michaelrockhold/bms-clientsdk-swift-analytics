/*
*     Copyright 2016 IBM Corp.
*     Licensed under the Apache License, Version 2.0 (the "License");
*     you may not use this file except in compliance with the License.
*     You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*     Unless required by applicable law or agreed to in writing, software
*     distributed under the License is distributed on an "AS IS" BASIS,
*     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*     See the License for the specific language governing permissions and
*     limitations under the License.
*/


import BMSCore


// Send methods
public extension Logger {
    
    
    internal static var currentlySendingLoggerLogs = false
    internal static var currentlySendingAnalyticsLogs = false
    
    
    /**
        Send the accumulated logs to the Bluemix server.

        Logger logs can only be sent if the BMSClient was initialized via the `initializeWithBluemixAppRoute()` method.

        - parameter completionHandler:  Optional callback containing the results of the send request
     */
    public static func send(completionHandler userCallback: BmsCompletionHandler? = nil) {
        
        guard !currentlySendingLoggerLogs else {
            #if swift(>=3.0)
                BMSLogger.internalLogger.info(message: "Ignoring Logger.send() until the previous send request finishes.")
            #else
                BMSLogger.internalLogger.info("Ignoring Logger.send() until the previous send request finishes.")
            #endif
            
            return
        }
        
        currentlySendingLoggerLogs = true
        
        let logSendCallback: BmsCompletionHandler = { (response: Response?, error: NSError?) in
            
            currentlySendingLoggerLogs = false
            
            if error == nil && response?.statusCode == 201 {
                
                #if swift(>=3.0)
                    BMSLogger.internalLogger.debug(message:"Client logs successfully sent to the server.")
                #else
                    BMSLogger.internalLogger.debug("Client logs successfully sent to the server.")
                #endif
                
                BMSLogger.delete(file: Constants.File.Logger.outboundLogs)
                
                // Remove the uncaught exception flag since the logs containing the exception(s) have just been sent to the server
                #if swift(>=3.0)
                    UserDefaults.standard.set(false, forKey: Constants.uncaughtException)
                #else
                    NSUserDefaults.standardUserDefaults().setBool(false, forKey: Constants.uncaughtException)
                #endif
            }
            else {
                #if swift(>=3.0)
                    BMSLogger.internalLogger.error(message: "Request to send client logs has failed.")
                #else
                    BMSLogger.internalLogger.error("Request to send client logs has failed.")
                #endif
            }
            
            userCallback?(response, error)
        }
        
        #if swift(>=3.0)
        
            // Use a serial queue to ensure that the same logs do not get sent more than once
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                do {
                    // Gather the logs and put them in a JSON object
                    let logsToSend: String? = try BMSLogger.getLogs(fromFile: Constants.File.Logger.logs, overflowFileName: Constants.File.Logger.overflowLogs, bufferFileName: Constants.File.Logger.outboundLogs)
                    var logPayloadData = try JSONSerialization.data(withJSONObject: [], options: [])
                    if let logPayload = logsToSend {
                        let logPayloadJson = [Constants.outboundLogPayload: logPayload]
                        logPayloadData = try JSONSerialization.data(withJSONObject: logPayloadJson, options: [])
                    }
                    
                    // Send the request, even if there are no logs to send (to keep track of device info)
                    if let request: BaseRequest = BMSLogger.buildLogSendRequest(completionHandler: logSendCallback) {
                        request.sendData(requestBody: logPayloadData, completionHandler: logSendCallback)
                    }
                }
                catch let error as NSError {
                    logSendCallback(nil, error)
                }
            })

        #else
        
            // Use a serial queue to ensure that the same logs do not get sent more than once
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) { () -> Void in
                do {
                    // Gather the logs and put them in a JSON object
                    let logsToSend: String? = try BMSLogger.getLogs(fromFile: Constants.File.Logger.logs, overflowFileName: Constants.File.Logger.overflowLogs, bufferFileName: Constants.File.Logger.outboundLogs)
                    var logPayloadData = try NSJSONSerialization.dataWithJSONObject([], options: [])
                    if let logPayload = logsToSend {
                        let logPayloadJson = [Constants.outboundLogPayload: logPayload]
                        logPayloadData = try NSJSONSerialization.dataWithJSONObject(logPayloadJson, options: [])
                    }
                    
                    // Send the request, even if there are no logs to send (to keep track of device info)
                    if let request: BaseRequest = BMSLogger.buildLogSendRequest(completionHandler: logSendCallback) {
                        request.sendData(logPayloadData, completionHandler: logSendCallback)
                    }
                }
                catch let error as NSError {
                    logSendCallback(nil, error)
                }
            }
        
        #endif

    }
    
    
    // Same as the other send() method but for analytics
    internal static func sendAnalytics(completionHandler userCallback: BmsCompletionHandler? = nil) {
        
        guard !currentlySendingAnalyticsLogs else {
            #if swift(>=3.0)
                Analytics.logger.info(message: "Ignoring Analytics.send() until the previous send request finishes.")
            #else
                Analytics.logger.info("Ignoring Analytics.send() until the previous send request finishes.")
            #endif
            
            return
        }
        
        currentlySendingAnalyticsLogs = true
        
        // Internal completion handler - wraps around the user supplied completion handler (if supplied)
        let analyticsSendCallback: BmsCompletionHandler = { (response: Response?, error: NSError?) in
            
            currentlySendingAnalyticsLogs = false
            
            #if swift(>=3.0)
            
                if error == nil && response?.statusCode == 201 {
                    Analytics.logger.debug(message: "Analytics data successfully sent to the server.")
                    
                    BMSLogger.delete(file: Constants.File.Analytics.outboundLogs)
                }
                else {
                    Analytics.logger.error(message: "Request to send analytics data to the server has failed.")
                }
                
            #else
                
                if error == nil && response?.statusCode == 201 {
                    Analytics.logger.debug("Analytics data successfully sent to the server.")
                    
                    BMSLogger.delete(file: Constants.File.Analytics.outboundLogs)
                }
                else {
                    Analytics.logger.error("Request to send analytics data to the server has failed.")
                }
                
            #endif
            
            userCallback?(response, error)
        }
        
        #if swift(>=3.0)
        
            // Use a serial queue to ensure that the same logs do not get sent more than once
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                do {
                    // Gather the logs and put them in a JSON object
                    let logsToSend: String? = try BMSLogger.getLogs(fromFile: Constants.File.Analytics.logs, overflowFileName: Constants.File.Analytics.overflowLogs, bufferFileName: Constants.File.Analytics.outboundLogs)
                    var logPayloadData = try JSONSerialization.data(withJSONObject: [], options: [])
                    if let logPayload = logsToSend {
                        let logPayloadJson = [Constants.outboundLogPayload: logPayload]
                        logPayloadData = try JSONSerialization.data(withJSONObject: logPayloadJson, options: [])
                    }
                    
                    // Send the request, even if there are no logs to send (to keep track of device info)
                    if let request: BaseRequest = BMSLogger.buildLogSendRequest(completionHandler: analyticsSendCallback) {
                        request.sendData(requestBody: logPayloadData, completionHandler: analyticsSendCallback)
                    }
                }
                catch let error as NSError {
                    analyticsSendCallback(nil, error)
                }
            })
                
        #else
                
            // Use a serial queue to ensure that the same analytics data do not get sent more than once
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) { () -> Void in
                do {
                    // Gather the logs and put them in a JSON object
                    let logsToSend: String? = try BMSLogger.getLogs(fromFile: Constants.File.Analytics.logs, overflowFileName: Constants.File.Analytics.overflowLogs, bufferFileName: Constants.File.Analytics.outboundLogs)
                    var logPayloadData = try NSJSONSerialization.dataWithJSONObject(["":""], options: [])
                    if let logPayload = logsToSend {
                        let logPayloadJson = [Constants.outboundLogPayload: logPayload]
                        logPayloadData = try NSJSONSerialization.dataWithJSONObject(logPayloadJson, options: [])
                    }
                    
                    // Send the request, even if there are no logs to send (to keep track of device info)
                    if let request: BaseRequest = BMSLogger.buildLogSendRequest(completionHandler: analyticsSendCallback) {
                        request.sendData(logPayloadData, completionHandler: analyticsSendCallback)
                    }
                }
                catch let error as NSError {
                    analyticsSendCallback(nil, error)
                }
            }
                
        #endif
    }
    
}



// MARK: -

/**
    `BMSLogger` provides the internal implementation of the BMSAnalyticsSpec `Logger` API.
 */
public class BMSLogger: LoggerDelegate {
    
    
    // MARK: Properties (internal)
    
    // Internal instrumentation for troubleshooting issues in BMSCore
    internal static let internalLogger = Logger.logger(forName: Constants.Package.logger)
    
    
    
    // MARK: Class constants (internal)
    
#if swift(>=3.0)
    
    // By default, the dateFormater will convert to the local time zone, but we want to send the date based on UTC
    // so that logs from all clients in all timezones are normalized to the same GMT timezone.
    internal static let dateFormatter: DateFormatter = BMSLogger.generateDateFormatter()
    
    private static func generateDateFormatter() -> DateFormatter {
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss:SSS"
        
        return formatter
    }
    
    // Path to the log files on the client device
    internal static let logsDocumentPath: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/"
    
    internal static let fileManager = FileManager.default
    
#else
    
    // By default, the dateFormater will convert to the local time zone, but we want to send the date based on UTC
    // so that logs from all clients in all timezones are normalized to the same GMT timezone.
    internal static let dateFormatter: NSDateFormatter = BMSLogger.generateDateFormatter()
    
    private static func generateDateFormatter() -> NSDateFormatter {
        
        let formatter = NSDateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(name: "GMT")
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss:SSS"
        
        return formatter
    }
    
    // Path to the log files on the client device
    internal static let logsDocumentPath: String = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] + "/"
    
    internal static let fileManager = NSFileManager.defaultManager()
    
#endif
    
    

    // MARK: - Uncaught exceptions
    
    /// True if the app crashed recently due to an uncaught exception.
    /// This property will be set back to `false` if the logs are sent to the server.
    public var isUncaughtExceptionDetected: Bool {
        
        get {
            #if swift(>=3.0)
                let asdf = UserDefaults.standard.bool(forKey: Constants.uncaughtException)
                return asdf
            #else
                return NSUserDefaults.standardUserDefaults().boolForKey(Constants.uncaughtException)
            #endif
        }
        set {
            #if swift(>=3.0)
                UserDefaults.standard.set(newValue, forKey: Constants.uncaughtException)
            #else
                NSUserDefaults.standardUserDefaults().setBool(newValue, forKey: Constants.uncaughtException)
            #endif
        }
    }
    
    // If the user set their own uncaught exception handler earlier, it gets stored here
    internal static let existingUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
    
    // This flag prevents infinite loops of uncaught exceptions
    internal static var exceptionHasBeenCalled = false
    
    internal static func startCapturingUncaughtExceptions() {
        
        NSSetUncaughtExceptionHandler { (uncaughtException: NSException) -> Void in
            
            if (!BMSLogger.exceptionHasBeenCalled) {
                // Persist a flag so that when the app starts back up, we can see if an exception occurred in the last session
                BMSLogger.exceptionHasBeenCalled = true
                
                BMSLogger.log(exception: uncaughtException)
                BMSAnalytics.logSessionEnd()
                
                BMSLogger.existingUncaughtExceptionHandler?(uncaughtException)
            }
        }
    }
    
    
    internal static func log(exception uncaughtException: NSException) {
        
        let logger = Logger.logger(forName: Constants.Package.logger)
        var exceptionString = "Uncaught Exception: \(uncaughtException.name)."
        if let reason = uncaughtException.reason {
            exceptionString += " Reason: \(reason)."
        }
        
        #if swift(>=3.0)
            logger.fatal(message: exceptionString)
        #else
            logger.fatal(exceptionString)
        #endif
    }
    
    
    
    // MARK: - Writing logs to file
    
    // We use serial queues to prevent race conditions when multiple threads try to read/modify the same file
    
#if swift(>=3.0)
    
    internal static let loggerFileIOQueue = DispatchQueue(label: "com.ibm.mobilefirstplatform.clientsdk.swift.BMSCore.Logger.loggerFileIOQueue")
    
    internal static let analyticsFileIOQueue = DispatchQueue(label: "com.ibm.mobilefirstplatform.clientsdk.swift.BMSCore.Logger.analyticsFileIOQueue")
    
#else
    
    internal static let loggerFileIOQueue: dispatch_queue_t = dispatch_queue_create("com.ibm.mobilefirstplatform.clientsdk.swift.BMSCore.Logger.loggerFileIOQueue", DISPATCH_QUEUE_SERIAL)
    
    
    internal static let analyticsFileIOQueue: dispatch_queue_t = dispatch_queue_create("com.ibm.mobilefirstplatform.clientsdk.swift.BMSCore.Logger.analyticsFileIOQueue", DISPATCH_QUEUE_SERIAL)
    
#endif
    
    
    // This is the master function that handles all of the logging, including level checking, printing to console, and writing to file
    // All other log functions below this one are helpers for this function
    public func logToFile(message logMessage: String, level: LogLevel, loggerName: String, calledFile: String, calledFunction: String, calledLineNumber: Int, additionalMetadata: [String: AnyObject]? = nil) {
        
        #if swift(>=3.0)
            let dispatchGroup = DispatchGroup()
        #else
            let dispatchGroup :dispatch_group_t = dispatch_group_create()
        #endif
        
        // Writing to file
        
        if level == LogLevel.Analytics {
            guard Analytics.enabled else {
                return
            }
        }
        else {
            guard Logger.logStoreEnabled else {
                return
            }
        }
        
        // Get file names and the dispatch queue needed to access those files
        let (logFile, logOverflowFile, fileDispatchQueue) = BMSLogger.getFiles(forLogLevel: level)
        
        #if swift(>=3.0)
        
            fileDispatchQueue.async(group: dispatchGroup, qos: DispatchQoS.default, flags: DispatchWorkItemFlags.noQoS, execute: {
                
                // Check if the log file is larger than the maxLogStoreSize. If so, move the log file to the "overflow" file, and start logging to a new log file. If an overflow file already exists, those logs get overwritten.
                if BMSLogger.isFull(file: logFile) {
                    do {
                        try BMSLogger.moveLogs(fromFile: logFile, toOverflowFile: logOverflowFile)
                    }
                    catch let error {
                        let logFileName = BMSLogger.extractFileName(fromPath: logFile)
                        print("Log file \(logFileName) is full but the old logs could not be removed. Try sending the logs. Error: \(error)")
                        return
                    }
                }
                
                let timeStampString = BMSLogger.dateFormatter.string(from: Date())
                var logAsJsonString = BMSLogger.convertToJson(message: logMessage, level: level, loggerName: loggerName, timeStamp: timeStampString, additionalMetadata: additionalMetadata)
                
                guard logAsJsonString != nil else {
                    let errorMessage = "Failed to write logs to file. This is likely because the analytics metadata could not be parsed."
                    
                    Logger.printToConsole(message: errorMessage, loggerName:loggerName, level: .Error, calledFunction: #function, calledFile: #file, calledLineNumber: #line)
                    
                    
                    return
                }
                
                logAsJsonString! += "," // Logs must be comma-separated
                
                BMSLogger.write(toFile: logFile, logMessage: logAsJsonString!, loggerName: loggerName)
            })
            
            let _ = dispatchGroup.wait(timeout: .distantFuture)
            
        #else
            
            dispatch_group_async(dispatchGroup, fileDispatchQueue) { () -> Void in
                // Check if the log file is larger than the maxLogStoreSize. If so, move the log file to the "overflow" file, and start logging to a new log file. If an overflow file already exists, those logs get overwritten.
                if BMSLogger.isFull(file: logFile) {
                    do {
                        try BMSLogger.moveLogs(fromFile: logFile, toOverflowFile: logOverflowFile)
                    }
                    catch let error {
                        let logFileName = BMSLogger.extractFileName(fromPath: logFile)
                        print("Log file \(logFileName) is full but the old logs could not be removed. Try sending the logs. Error: \(error)")
                        return
                    }
                }
                
                let timeStampString = BMSLogger.dateFormatter.stringFromDate(NSDate())
                var logAsJsonString = BMSLogger.convertToJson(message: logMessage, level: level, loggerName: loggerName, timeStamp: timeStampString, additionalMetadata: additionalMetadata)
                
                guard logAsJsonString != nil else {
                    let errorMessage = "Failed to write logs to file. This is likely because the analytics metadata could not be parsed."
                    
                    Logger.printToConsole(message: errorMessage, loggerName:loggerName, level: .Error, calledFunction: #function, calledFile: #file, calledLineNumber: #line)
                    
                    
                    return
                }
                
                logAsJsonString! += "," // Logs must be comma-separated
                
                BMSLogger.write(toFile: logFile, logMessage: logAsJsonString!, loggerName: loggerName)
            }
            
            dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER)
            
        #endif
    }
    
    
#if swift(>=3.0)
    
    // Get the full path to the log file and overflow file, and get the dispatch queue that they need to be operated on.
    internal static func getFiles(forLogLevel level: LogLevel) -> (String, String, DispatchQueue) {
        
        var logFile: String = BMSLogger.logsDocumentPath
        var logOverflowFile: String = BMSLogger.logsDocumentPath
        var fileDispatchQueue: DispatchQueue
        
        if level == LogLevel.Analytics {
            logFile += Constants.File.Analytics.logs
            logOverflowFile += Constants.File.Analytics.overflowLogs
            fileDispatchQueue = BMSLogger.analyticsFileIOQueue
        }
        else {
            logFile += Constants.File.Logger.logs
            logOverflowFile += Constants.File.Logger.overflowLogs
            fileDispatchQueue = BMSLogger.loggerFileIOQueue
        }
        
        return (logFile, logOverflowFile, fileDispatchQueue)
    }
    
#else
    
    // Get the full path to the log file and overflow file, and get the dispatch queue that they need to be operated on.
    internal static func getFiles(forLogLevel level: LogLevel) -> (String, String, dispatch_queue_t) {
        
        var logFile: String = BMSLogger.logsDocumentPath
        var logOverflowFile: String = BMSLogger.logsDocumentPath
        var fileDispatchQueue: dispatch_queue_t
        
        if level == LogLevel.Analytics {
            logFile += Constants.File.Analytics.logs
            logOverflowFile += Constants.File.Analytics.overflowLogs
            fileDispatchQueue = BMSLogger.analyticsFileIOQueue
        }
        else {
            logFile += Constants.File.Logger.logs
            logOverflowFile += Constants.File.Logger.overflowLogs
            fileDispatchQueue = BMSLogger.loggerFileIOQueue
        }
        
        return (logFile, logOverflowFile, fileDispatchQueue)
    }
    
#endif
    
    
    // Check if the log file size exceeds the limit set by the Logger.maxLogStoreSize property
    // Logs are actually distributed evenly between a "normal" log file and an "overflow" file, but we only care if the "normal" log file is full (half of the total maxLogStoreSize)
    internal static func isFull(file logFile: String) -> Bool {
        
        #if swift(>=3.0)
        
            if (BMSLogger.fileManager.fileExists(atPath: logFile)) {
                
                do {
                    let attr : NSDictionary? = try FileManager.default.attributesOfItem(atPath: logFile)
                    if let currentLogFileSize = attr?.fileSize() {
                        return currentLogFileSize > Logger.maxLogStoreSize / 2 // Divide by 2 since the total log storage gets shared between the log file and the overflow file
                    }
                }
                catch let error {
                    let logFile = BMSLogger.extractFileName(fromPath: logFile)
                    print("Cannot determine the size of file:\(logFile) due to error: \(error). In case the file size is greater than the specified max log storage size, logs will not be written to file.")
                }
            }
            
        #else
            
            if (BMSLogger.fileManager.fileExistsAtPath(logFile)) {
                
                do {
                    let attr : NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(logFile)
                    if let currentLogFileSize = attr?.fileSize() {
                        return currentLogFileSize > Logger.maxLogStoreSize / 2 // Divide by 2 since the total log storage gets shared between the log file and the overflow file
                    }
                }
                catch let error {
                    let logFile = BMSLogger.extractFileName(fromPath: logFile)
                    print("Cannot determine the size of file:\(logFile) due to error: \(error). In case the file size is greater than the specified max log storage size, logs will not be written to file.")
                }
            }
            
        #endif
        
        return false
    }
    
    
    // When the log file is full, the old logs are moved to the overflow file to make room for new logs
    internal static func moveLogs(fromFile logFile: String, toOverflowFile overflowFile: String) throws {
        
        #if swift(>=3.0)
            if BMSLogger.fileManager.fileExists(atPath: overflowFile) && BMSLogger.fileManager.isDeletableFile(atPath: overflowFile) {
                try BMSLogger.fileManager.removeItem(atPath: overflowFile)
            }
            try BMSLogger.fileManager.moveItem(atPath: logFile, toPath: overflowFile)
        #else
            if BMSLogger.fileManager.fileExistsAtPath(overflowFile) && BMSLogger.fileManager.isDeletableFileAtPath(overflowFile) {
                try BMSLogger.fileManager.removeItemAtPath(overflowFile)
            }
            try BMSLogger.fileManager.moveItemAtPath(logFile, toPath: overflowFile)
        #endif
    }
    
    
    // Convert log message and metadata into JSON format. This is the actual string that gets written to the log files.
    internal static func convertToJson(message logMessage: String, level: LogLevel, loggerName: String, timeStamp: String, additionalMetadata: [String: AnyObject]?) -> String? {
        
        var logMetadata: [String: AnyObject] = [:]
        logMetadata[Constants.Metadata.Logger.timestamp] = timeStamp
        logMetadata[Constants.Metadata.Logger.level] = level.stringValue
        logMetadata[Constants.Metadata.Logger.package] = loggerName
        logMetadata[Constants.Metadata.Logger.message] = logMessage
        if additionalMetadata != nil {
            logMetadata[Constants.Metadata.Logger.metadata] = additionalMetadata! // Typically only available if the Logger.analytics method was called
        }
        
        #if swift(>=3.0)
            
            let logData: Data
            do {
                logData = try JSONSerialization.data(withJSONObject: logMetadata, options: [])
            }
            catch {
                return nil
            }
            
            return String(data: logData, encoding: .utf8)
        
        #else
            
            let logData: NSData
            do {
                logData = try NSJSONSerialization.dataWithJSONObject(logMetadata, options: [])
            }
            catch {
                return nil
            }
            
            return String(data: logData, encoding: NSUTF8StringEncoding)
            
        #endif
    }
    
    
    // Append log message to the end of the log file
    internal static func write(toFile file: String, logMessage: String, loggerName: String) {
        
        #if swift(>=3.0)
            
            if !BMSLogger.fileManager.fileExists(atPath: file) {
                BMSLogger.fileManager.createFile(atPath: file, contents: nil, attributes: nil)
            }
            
            let fileHandle = FileHandle(forWritingAtPath: file)
            let data = logMessage.data(using: .utf8)
            
        #else
            
            if !BMSLogger.fileManager.fileExistsAtPath(file) {
                BMSLogger.fileManager.createFileAtPath(file, contents: nil, attributes: nil)
            }
            
            let fileHandle = NSFileHandle(forWritingAtPath: file)
            let data = logMessage.dataUsingEncoding(NSUTF8StringEncoding)
            
        #endif
        
        if fileHandle != nil && data != nil {
            fileHandle!.seekToEndOfFile()
            #if swift(>=3.0)
                fileHandle!.write(data!)
            #else
                fileHandle!.writeData(data!)
            #endif
            fileHandle!.closeFile()
        }
        else {
            let errorMessage = "Cannot write to file: \(file)."

            Logger.printToConsole(message: errorMessage, loggerName: loggerName, level: LogLevel.Error, calledFunction: #function, calledFile: #file, calledLineNumber: #line)
        }
        
    }
    
    
    // When logging messages to the user, make sure to only mention the log file name, not the full path since it may contain sensitive data unique to the device.
    internal static func extractFileName(fromPath filePath: String) -> String {
        
        var logFileName = Constants.File.unknown
        
        #if swift(>=3.0)
            let fileUrl = URL(string: filePath)
            
            if let lastPathComponent = fileUrl?.lastPathComponent, lastPathComponent.characters.count > 0 {
                logFileName = lastPathComponent
            }
        #else
            let fileUrl = NSURL(string: filePath)
            
            if let lastPathComponent = fileUrl?.lastPathComponent where lastPathComponent.characters.count > 0 {
                logFileName = lastPathComponent
            }
        #endif
        
        return logFileName
    }
    
    
    
    // MARK: - Sending logs
    
    // Build the Request object that will be used to send the logs to the server
    internal static func buildLogSendRequest(completionHandler callback: BmsCompletionHandler) -> BaseRequest? {
        
        let bmsClient = BMSClient.sharedInstance
        var headers: [String: String] = ["Content-Type": "text/plain"]
        var logUploadUrl = ""
        
        // Check that the BMSClient class has been initialized before building the upload URL
        // Only the region is needed to communicate with the Analytics service. App route and GUID are not required.
        if bmsClient.bluemixRegion != nil && bmsClient.bluemixRegion != "" {
            guard BMSAnalytics.apiKey != nil && BMSAnalytics.apiKey != "" else {
                returnInitializationError(className: "Analytics", missingValue: "apiKey", callback: callback)
                return nil
            }
            headers[Constants.analyticsApiKey] = BMSAnalytics.apiKey!
            if let appGuid = BMSClient.sharedInstance.bluemixAppGUID {
                headers[Constants.analyticsP30ApiKey] = appGuid
            }
            
            logUploadUrl = "https://" + Constants.AnalyticsServer.hostName + bmsClient.bluemixRegion! + Constants.AnalyticsServer.uploadPath
            
            // Request class is specific to Bluemix (since it uses Bluemix authorization managers)
            return Request(url: logUploadUrl, headers: headers, queryParameters: nil, method: HttpMethod.POST)
        }
        else {
            #if swift(>=3.0)
                BMSLogger.internalLogger.error(message: "Failed to send logs because the client was not yet initialized. Make sure that the BMSClient class has been initialized.")
            #else
                BMSLogger.internalLogger.error("Failed to send logs because the client was not yet initialized. Make sure that the BMSClient class has been initialized.")
            #endif
            
            return nil
        }
    }
    
    
    // If this is reached, the user most likely failed to initialize BMSClient or Analytics
    internal static func returnInitializationError(className uninitializedClass: String, missingValue: String, callback: BmsCompletionHandler) {
        
        #if swift(>=3.0)
            BMSLogger.internalLogger.error(message: "No value found for the \(uninitializedClass) \(missingValue) property.")
        #else
            BMSLogger.internalLogger.error("No value found for the \(uninitializedClass) \(missingValue) property.")
        #endif
        
        let errorMessage = "Must initialize \(uninitializedClass) before sending logs to the server."
        
        var errorCode: Int
        switch uninitializedClass {
        case "Analytics":
            errorCode = BMSAnalyticsError.AnalyticsNotInitialized.rawValue
        case "BMSClient":
            errorCode = BMSCoreError.ClientNotInitialized.rawValue
        default:
            errorCode = -1
        }
        
        let error = NSError(domain: BMSAnalyticsError.domain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        
        callback(nil, error)
    }
    
    
    // Read the logs from file, move them to the "send" buffer file, and return the logs
    internal static func getLogs(fromFile fileName: String, overflowFileName: String, bufferFileName: String) throws -> String? {
        
        let logFile = BMSLogger.logsDocumentPath + fileName // Original log file
        let overflowLogFile = BMSLogger.logsDocumentPath + overflowFileName // Extra file in case original log file got full
        let bufferLogFile = BMSLogger.logsDocumentPath + bufferFileName // Temporary file for sending logs
        
        #if swift(>=3.0)
        
            // First check if the "*.log.send" buffer file already contains logs. This will be the case if the previous attempt to send logs failed.
            if BMSLogger.fileManager.isReadableFile(atPath: bufferLogFile) {
                return try readLogs(fromFile: bufferLogFile)
            }
            else if BMSLogger.fileManager.isReadableFile(atPath: logFile) {
                // Merge the logs from the normal log file and the overflow log file (if necessary)
                if BMSLogger.fileManager.isReadableFile(atPath: overflowLogFile) {
                    let fileContents = try String(contentsOfFile: overflowLogFile, encoding: .utf8)
                    
                    BMSLogger.write(toFile: logFile, logMessage: fileContents, loggerName: BMSLogger.internalLogger.name)
                }
                
                // Since the buffer log is empty, we move the log file to the buffer file in preparation of sending the logs. When new logs are recorded, a new log file gets created to replace it.
                try BMSLogger.fileManager.moveItem(atPath: logFile, toPath: bufferLogFile)
                return try readLogs(fromFile: bufferLogFile)
            }
            else {
                BMSLogger.internalLogger.debug(message: "Unable to read file: \(fileName). This is likely because either no analytics data or no logs have been recorded since they were last sent.")
                return nil
            }
            
        #else
        
            // First check if the "*.log.send" buffer file already contains logs. This will be the case if the previous attempt to send logs failed.
            if BMSLogger.fileManager.isReadableFileAtPath(bufferLogFile) {
                return try readLogs(fromFile: bufferLogFile)
            }
            else if BMSLogger.fileManager.isReadableFileAtPath(logFile) {
                // Merge the logs from the normal log file and the overflow log file (if necessary)
                if BMSLogger.fileManager.isReadableFileAtPath(overflowLogFile) {
                    let fileContents = try NSString(contentsOfFile: overflowLogFile, encoding: NSUTF8StringEncoding) as String
                    BMSLogger.write(toFile: logFile, logMessage: fileContents, loggerName: BMSLogger.internalLogger.name)
                }
                
                // Since the buffer log is empty, we move the log file to the buffer file in preparation of sending the logs. When new logs are recorded, a new log file gets created to replace it.
                try BMSLogger.fileManager.moveItemAtPath(logFile, toPath: bufferLogFile)
                return try readLogs(fromFile: bufferLogFile)
            }
            else {
                BMSLogger.internalLogger.debug("Unable to read file: \(fileName). This is likely because either no analytics data or no logs have been recorded since they were last sent.")
                return nil
            }

        #endif
    }
    
    
    // We should only be sending logs from a buffer file, which is a copy of the normal log file. This way, if the logs fail to get sent to the server, we can hold onto them until the send succeeds, while continuing to log to the normal log file.
    internal static func readLogs(fromFile bufferLogFile: String) throws -> String? {
        
        let analyticsOutboundLogs: String = BMSLogger.logsDocumentPath + Constants.File.Analytics.outboundLogs
        let loggerOutboundLogs: String = BMSLogger.logsDocumentPath + Constants.File.Logger.outboundLogs
        
        
        var fileContents: String?
        
        do {
            // Before sending the logs, we need to read them from the file. This is done in a serial dispatch queue to prevent conflicts if the log file is simulatenously being written to.
            switch bufferLogFile {
            case analyticsOutboundLogs:
                try dispatch_sync_throwable(BMSLogger.analyticsFileIOQueue, block: { () -> () in
                    #if swift(>=3.0)
                        fileContents = try String(contentsOfFile: bufferLogFile, encoding: .utf8)
                    #else
                        fileContents = try NSString(contentsOfFile: bufferLogFile, encoding: NSUTF8StringEncoding) as String
                    #endif
                })
            case loggerOutboundLogs:
                try dispatch_sync_throwable(BMSLogger.loggerFileIOQueue, block: { () -> () in
                    #if swift(>=3.0)
                        fileContents = try String(contentsOfFile: bufferLogFile, encoding: .utf8)
                    #else
                        fileContents = try NSString(contentsOfFile: bufferLogFile, encoding: NSUTF8StringEncoding) as String
                    #endif
                })
            default:
                #if swift(>=3.0)
                    BMSLogger.internalLogger.error(message: "Cannot send data to server. Unrecognized file: \(bufferLogFile).")
                #else
                    BMSLogger.internalLogger.error("Cannot send data to server. Unrecognized file: \(bufferLogFile).")
                #endif
            }
        }
        
        return fileContents
    }
    
    
    // For deleting files where only the file name is supplied, not the full path
    internal static func delete(file fileName: String) {
        
        let pathToFile = BMSLogger.logsDocumentPath + fileName
        
        #if swift(>=3.0)
        
            if BMSLogger.fileManager.fileExists(atPath: pathToFile) && BMSLogger.fileManager.isDeletableFile(atPath: pathToFile) {
                do {
                    try BMSLogger.fileManager.removeItem(atPath: pathToFile)
                }
                catch let error {
                    BMSLogger.internalLogger.error(message: "Failed to delete log file \(fileName) after sending. Error: \(error)")
                }
            }
            
        #else
        
            if BMSLogger.fileManager.fileExistsAtPath(pathToFile) && BMSLogger.fileManager.isDeletableFileAtPath(pathToFile) {
                do {
                    try BMSLogger.fileManager.removeItemAtPath(pathToFile)
                }
                catch let error {
                    BMSLogger.internalLogger.error("Failed to delete log file \(fileName) after sending. Error: \(error)")
                }
            }
        
        #endif
    }

}


// MARK: - Helper

#if swift(>=3.0)

// Custom dispatch_sync that can incorporate throwable statements
internal func dispatch_sync_throwable(_ queue: DispatchQueue, block: () throws -> ()) throws {
    
    var error: Error?
    queue.sync(execute: {
        do {
            try block()
        }
        catch let caughtError {
            error = caughtError
        }
    })
    if error != nil {
        throw error!
    }
}

#else

// Custom dispatch_sync that can incorporate throwable statements
internal func dispatch_sync_throwable(queue: dispatch_queue_t, block: () throws -> ()) throws {
    
    var error: ErrorType?
    dispatch_sync(queue) {
        do {
            try block()
        }
        catch let caughtError {
            error = caughtError
        }
    }
    if error != nil {
        throw error!
    }
}

#endif
