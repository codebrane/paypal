# paypal
One stop shop for preparing images for selling online via PayPal

## Usage
swift paypal.swift IMAGE NAME TYPE

IMAGE refers to the image you want to sell. e.g. N3.jpg  
NAME is the title of the image. This is what will be displayed in the shopping cart  
TYPE refers to a predefined pricing type in paypal.plist

If you have a great photograph you took with your Nikon DSLR, your native resolution is around 18x12in. Scaling up to 30x20in for a truly superb print and scaling down to 15x10 for a more manageable product means you would have these defined in paypal.plist:

```xml
<key>Nikon</key>
<array>
	<string>30x20in:150</string>
	<string>18x12in:100</string>
	<string>15x10in:50</string>
</array>
```

Each entry in the Nikon array refers to the size and price. e.g. the 30x20in print sells for 150 units. The units are determined by the PayPalCurrency entry in paypal.plist.

You can sell the above image online by using:

<pre>
	swift paypal.swift N3.jpg "Mountain Mists" Nikon
</pre>

Your original image will be resized to N3-300x300.jpg (for mobile devices) and N3-400x400.jpg (desktop devices). The program will also generate an Add To Cart button and View Cart button for the image that you copy/paste into your shop's webpage. You only need one View Cart button for all image pages though.

## Customisation
Replace the ImageMagick and PayPal settings in paypal.plist with your own
