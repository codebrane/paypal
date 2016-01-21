import Foundation
import Darwin

struct PayPal {
	var apiVersion = "";
	var apiURL = "";
	var user = "";
	var password = "";
	var signature = "";
}

struct PrintSizeAndPrice {
	var size = "";
	var price = "";
}

func readConfig(filename:String) -> Dictionary<String, AnyObject>? {
	return NSDictionary(contentsOfFile: filename) as? Dictionary<String, AnyObject>
}

func resizeImage(command: String, args: [String]) -> String {
	let task = NSTask()
	task.launchPath = command
	task.arguments = args
	let pipe = NSPipe()
	task.standardOutput = pipe
	task.launch()
	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	let output: String = String(data: data, encoding: NSUTF8StringEncoding)!
	return output
}

func createAddToCartButton(paypal:PayPal, printSizesAndPrices:[PrintSizeAndPrice], imageTitle:String,
	completionHandler: ((NSURLResponse!, NSData?, NSError?) -> Void)) {
		
		let request : NSMutableURLRequest = NSMutableURLRequest()
		let url: String! = "\(paypal.apiURL)"
		request.URL = NSURL(string: url)
		request.HTTPMethod = "POST"
		
		var httpBody = "USER=\(paypal.user)" + "&"
		httpBody += "PWD=\(paypal.password)" + "&"
		httpBody += "SIGNATURE=\(paypal.signature)" + "&"
		httpBody += "VERSION=\(paypal.apiVersion)" + "&"
		httpBody += "METHOD=BMCreateButton" + "&"
				
		httpBody += "BUTTONCODE=HOSTED" + "&"
		httpBody += "BUTTONTYPE=CART" + "&"
		
		httpBody += "L_BUTTONVAR1=item_name=\(imageTitle)" + "&"
		httpBody += "L_BUTTONVAR2=currency_code=GBP" + "&"
		httpBody += "L_BUTTONVAR3=no_note=1" + "&"
		httpBody += "OPTION0NAME=Print Size" + "&"
		
		var count = 0
		for printSizeAndPrice in printSizesAndPrices {
			httpBody += "L_OPTION0SELECT\(count)=\(printSizeAndPrice.size)" + "&"
			httpBody += "L_OPTION0PRICE\(count)=\(printSizeAndPrice.price)" + "&"
			count++
		}
		
		httpBody += "HOSTEDBUTTONID=N3"
				
		let httpBodyData:NSData = httpBody.dataUsingEncoding(NSUTF8StringEncoding)!
		request.HTTPBody = httpBodyData
		
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		let session = NSURLSession(configuration: config)
		let task = session.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
			completionHandler(response, data, error)
		});
		task.resume()
}

func createViewCartButton(paypal:PayPal,
	completionHandler: ((NSURLResponse!, NSData?, NSError?) -> Void)) {
		
		let request : NSMutableURLRequest = NSMutableURLRequest()
		let url: String! = "\(paypal.apiURL)"
		request.URL = NSURL(string: url)
		request.HTTPMethod = "POST"
		
		var httpBody = "USER=\(paypal.user)" + "&"
		httpBody += "PWD=\(paypal.password)" + "&"
		httpBody += "SIGNATURE=\(paypal.signature)" + "&"
		httpBody += "VERSION=\(paypal.apiVersion)" + "&"
		httpBody += "METHOD=BMCreateButton" + "&"
				
		httpBody += "BUTTONCODE=CLEARTEXT" + "&"
		httpBody += "BUTTONTYPE=VIEWCART" + "&"
		
		let httpBodyData:NSData = httpBody.dataUsingEncoding(NSUTF8StringEncoding)!
		request.HTTPBody = httpBodyData
		
		let config = NSURLSessionConfiguration.defaultSessionConfiguration()
		let session = NSURLSession(configuration: config)
		let task = session.dataTaskWithRequest(request, completionHandler: {(data, response, error) in
			completionHandler(response, data, error)
		});
		task.resume()
}

func matchesForRegexInText(regex: String!, text: String!) -> [String] {
	do {
		let regex = try NSRegularExpression(pattern: regex, options: [])
		let nsString = text as NSString
		let results = regex.matchesInString(text, options: [], range: NSMakeRange(0, nsString.length))
		return results.map { nsString.substringWithRange($0.range)}
	} catch let error as NSError {
		print("invalid regex: \(error.localizedDescription)")
		return []
	}
}

let args = [String](Process.arguments)
if (args.count != 4) {
	print("usage: swift paypal.swift IMAGE NAME TYPE")
	print("e.g. swift paypal.swift N3.jpg Sentinel Nikon")
	print("TYPE refers to the sizes and pricing of the image")
	print("output will be:")
	print("N3-300x300.jpg and N3-400x400.jpg")
	print("Add To Cart and View Cart buttons")
	exit(0)
}

let config = readConfig("paypal.plist")!

let image = args[1]
let imageTitle = args[2]
let imageType = args[3]

if config[imageType] == nil {
	print("\(imageType)? I don't know what that is!")
	exit(0)
}

let imageParts = image.characters.split{$0 == "."}.map(String.init)
let imageName = imageParts[0]
let imageExt = imageParts[1]

var imResizeCommand = config["ImageMagickConvert"] as! String

var size = "400x400"
print("resizing \(image) to \(size)")
resizeImage(imResizeCommand, args:[image, "-resize", size, "\(imageName)-\(size).\(imageExt)"])
size = "300x300"
print("resizing \(image) to \(size)")
resizeImage(imResizeCommand, args:[image, "-resize", size, "\(imageName)-\(size).\(imageExt)"])

var SEMAPHORE = false

var paypal = PayPal()
paypal.apiVersion = config["PayPalVersion"] as! String
paypal.apiURL = config["PayPalAPIURL"] as! String
paypal.user = config["PayPalUser"] as! String
paypal.password = config["PayPalPassword"] as! String
paypal.signature = config["PayPalSignature"] as! String

var printSizesAndPrices = [PrintSizeAndPrice]()
let sizesAndPrices = config[imageType] as! [String]
for sizePriceCombo in sizesAndPrices {
	let parts = sizePriceCombo.characters.split{$0 == ":"}.map(String.init)
	var printSizeAndPrice = PrintSizeAndPrice()
	printSizeAndPrice.size = parts[0]
	printSizeAndPrice.price = parts[1]
	printSizesAndPrices.append(printSizeAndPrice)
}

print("creating Add To Cart button")
var addToCartButton:String?
createAddToCartButton(paypal, printSizesAndPrices:printSizesAndPrices, imageTitle:imageTitle) { response, data, error in
	var datastring = NSString(data:data!, encoding:NSUTF8StringEncoding)
	var responseData = datastring as! String
	let matches = matchesForRegexInText("form.*form", text: responseData)
	let urlEncodedButtonString = "<\(matches[0])>"
	addToCartButton = urlEncodedButtonString.stringByRemovingPercentEncoding!
	SEMAPHORE = true
}
while(!SEMAPHORE) {}
SEMAPHORE = false
print("----------------------------------------")
print(addToCartButton!)
print("----------------------------------------")

print("creating View Cart button")
var viewCartButton:String?
createViewCartButton(paypal) { response, data, error in
	var datastring = NSString(data:data!, encoding:NSUTF8StringEncoding)
	var responseData = datastring as! String
	let matches = matchesForRegexInText("form.*form", text: responseData)
	let urlEncodedButtonString = "<\(matches[0])>"
	viewCartButton = urlEncodedButtonString.stringByRemovingPercentEncoding!
	SEMAPHORE = true
}
while(!SEMAPHORE) {}
SEMAPHORE = false
print("----------------------------------------")
print(viewCartButton!)
print("----------------------------------------")
