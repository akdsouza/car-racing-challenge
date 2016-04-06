//
//  PurchaseController.swift
//  Car Racing Challenge
//
//  Created by Alex Ongarato on 27/03/15.
//  Copyright (c) 2015 Alex Ongarato. All rights reserved.
//

import Foundation
import StoreKit

private var _instance           : PurchaseController!;
private var _hasPurchased       : Bool = false;
private var _transactionType    : Int = -1;
private var _productsRequest    : SKProductsRequest!;

class PurchaseController:NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver
{
    private var productsIDs:NSDictionary!;
    
    class func getInstance() -> PurchaseController
    {
        if(_instance == nil)
        {
            _instance = PurchaseController();
        }
        return _instance;
    }
    
    override init()
    {
        super.init();
        
        if let url:NSURL = NSBundle.mainBundle().URLForResource("Products",  withExtension:"plist")
        {
            if let dict:NSDictionary = NSDictionary(contentsOfURL:url)
            {
                self.productsIDs = dict;
            }
        }
        
        _hasPurchased = (Configs.FULL_VERSION_MODE) ? true : DataProvider.getBoolData(SuiteNames.SuiteConfigs, key: SuiteNames.KeyAds);
    }
    
    func hasPurchased() -> Bool
    {
        return _hasPurchased;
    }
    
    func hasPurchased(value:Bool)
    {
        DataProvider.saveData(SuiteNames.SuiteConfigs, key: SuiteNames.KeyAds, value: value);
        _hasPurchased = value;
    }
    
    func userCanPurchase() -> Bool
    {
        return SKPaymentQueue.canMakePayments();
    }
    /*
    func showDefaultPurchaseMessage(completion:(()->Void)!)
    {
        AlertController.getInstance().showAlert(title: "FREE VERSION", message: "It's Only available while online.\nTry the full version now!", action: "OK", completion: completion);
    }
    */
    func buyRemoveAds(tryRestore:Bool)
    {
        if(self.productsIDs == nil)
        {
            Trace("Remove Ads handler ERROR");
            return;
        }
        
        _transactionType = tryRestore ? 1 : 0;
        
        Trace("Remove Ads handler");
        
        if let id = self.productsIDs.valueForKey("remove_ads") as? String
        {
            Trace("validating Remove Ads ID:\(id)...");
            AlertController.getInstance().showAlert(nil, message: "please wait...", action: nil, completion:nil);// {
                self.validateProductIdentifiers([id]);
//            });
        }
        else
        {
            Trace("Remove Ad ID not found");
            AlertController.getInstance().showAlert("Remove Ad", message: "Sorry. Something went wrong. Please try again.", completion: nil);
        }
    }
    
    private func validateProductIdentifiers(productIdentifiers:Set<String>!)
    {
        if(!ConnectivityHelper.isReachable())
        {
            ConnectivityHelper.showDefaultOfflineMessage();
            return;
        }
        
        if(_productsRequest != nil)
        {
            _productsRequest.cancel();
            _productsRequest.delegate = nil;
            _productsRequest = nil;
        }
        
        _productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers);
        _productsRequest.delegate = self;
        _productsRequest.start();
        
        //calls productsRequest(request: SKProductsRequest!, didReceiveResponse response: SKProductsResponse!)
    }
    
    
    //---------------- observers --------------
    @objc func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse)
    {
        if let valid:NSArray = response.products
        {
            for validIdentifier in valid
            {
                if let prod = validIdentifier as? SKProduct
                {
                    var numberFormatter:NSNumberFormatter = NSNumberFormatter();
                    numberFormatter.formatterBehavior = NSNumberFormatterBehavior.Behavior10_4;
                    numberFormatter.numberStyle = NSNumberFormatterStyle.CurrencyStyle;
                    numberFormatter.locale = prod.priceLocale;
                    var formattedPrice:NSString = numberFormatter.stringFromNumber(prod.price)!;
                    
                    func startPayment()
                    {
                        SKPaymentQueue.defaultQueue().addTransactionObserver(self);
                        
                        if(_transactionType == 0)
                        {
                            Trace("starting payment process...");
                            let payment:SKMutablePayment = SKMutablePayment(product: prod);
                            payment.quantity = 1;
                            SKPaymentQueue.defaultQueue().addPayment(payment);
                        }
                        else if(_transactionType == 1)
                        {
                            Trace("starting restore payment process...");
                            SKPaymentQueue.defaultQueue().restoreCompletedTransactions();
                        }
                        
                        _transactionType = -1;
                    }
                    
                    _productsRequest.delegate = nil;
                    startPayment();
                    return;
                }
                else
                {
                    Trace("valid product failed");
                }
            }
            
            Trace("valid products count:\(valid.count)");
        }
        
        if let invalid:NSArray = response.invalidProductIdentifiers
        {
            for _ in invalid
            {
                AlertController.getInstance().showAlert("Error", message: "The product requested is currently unavailable. Try again later.", action: "OK", completion: nil);
                break;
            }
            
            Trace("invalid products count:\(invalid.count)");
        }
    }
    
    func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
    {
        
        var failed:Bool = false;
        var purchased:Bool = false;
        
        Trace("paymentQueue updateTransactions");
        
        if let prodID = self.productsIDs.valueForKey("remove_ads") as? String
        {
            for transaction in transactions
            {
                Trace("product: \(transaction.payment.productIdentifier), state \(transaction.transactionState.rawValue)");
                
                if(transaction.payment.productIdentifier == prodID)
                {
                    switch (transaction.transactionState)
                    {
                    case SKPaymentTransactionState.Purchasing:
                        Trace("Purchasing");
                        break;
                    case SKPaymentTransactionState.Deferred:
                        Trace("Deferred");
                        failed = true;
                        break;
                    case SKPaymentTransactionState.Failed:
                        Trace("Failed");
//                                failed = true;
                        AlertController.getInstance().hideAlert(nil);
                        break;
                    case SKPaymentTransactionState.Purchased:
                        Trace("Purchased");
                        purchased = true;
                        break;
                    case SKPaymentTransactionState.Restored:
                        Trace("Restored");
                        purchased = true;
                        break;
                    }
                }
            }
        }
        else
        {
            AlertController.getInstance().showAlert("Error", message: "Oops!\nAn error occurred.\nCode:001", action: "OK");
        }
        
        if(failed)
        {
            AlertController.getInstance().showAlert("Failed", message: "\nPurchase not completed.\n\nTry again later.\n", action: "OK");
        }
        
        if(purchased)
        {
            NSNotificationCenter.defaultCenter().postNotificationName(Events.AdsPurchased, object:self);
            return;
        }
    }
  /*
    func paymentQueue(queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
        
    }
    
    func paymentQueue(queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        
    }
    
    func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
        
    }
 */
}