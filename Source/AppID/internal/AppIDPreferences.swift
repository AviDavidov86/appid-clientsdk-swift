/*
 *     Copyright 2015 IBM Corp.
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


internal class AppIDPreferences {
    
    internal static var sharedPreferences:UserDefaults = UserDefaults.standard
    internal var persistencePolicy:PolicyPreference
    internal var clientId:StringPreference
    internal var registrationTenantId:StringPreference
    internal var accessToken:TokenPreference
    internal var idToken:TokenPreference
    internal var userIdentity:JSONPreference
    internal var deviceIdentity:JSONPreference
    internal var appIdentity:JSONPreference
    
    
    internal init() {
        
        persistencePolicy = PolicyPreference(prefName: BMSSecurityConstants.PERSISTENCE_POLICY_LABEL, defaultValue: PersistencePolicy.always, idToken: nil, accessToken: nil)
        clientId = StringPreference(prefName: BMSSecurityConstants.clientIdLabel)
        registrationTenantId = StringPreference(prefName: BMSSecurityConstants.tenantIdLabel)
        accessToken  = TokenPreference(prefName: BMSSecurityConstants.accessTokenLabel, persistencePolicy: persistencePolicy)
        idToken  = TokenPreference(prefName: BMSSecurityConstants.idTokenLabel, persistencePolicy: persistencePolicy)
        persistencePolicy.idToken = idToken
        persistencePolicy.accessToken = accessToken
        userIdentity  = JSONPreference(prefName: BMSSecurityConstants.USER_IDENTITY_LABEL)
        deviceIdentity  = JSONPreference(prefName : BMSSecurityConstants.DEVICE_IDENTITY_LABEL)
        appIdentity  = JSONPreference(prefName: BMSSecurityConstants.APP_IDENTITY_LABEL)
    }
}


/**
 * Holds single string preference value
 */
internal class StringPreference {
    
    var prefName:String
    var value:String?
    
    internal convenience init(prefName:String) {
        self.init(prefName: prefName, defaultValue: nil)
    }
    
    internal init(prefName:String, defaultValue:String?) {
        self.prefName = prefName
        if let val = AppIDPreferences.sharedPreferences.value(forKey: prefName) as? String {
            self.value = val
        } else {
            self.value = defaultValue
        }
    }
    internal func get() ->String?{
        return value
    }
    

    internal func set(_ value:String?) {
        self.value = value
        commit()
    }

    
    internal func clear() {
        self.value = nil
        commit()
    }
    
    private func commit() {
        AppIDPreferences.sharedPreferences.setValue(value, forKey: prefName)
        AppIDPreferences.sharedPreferences.synchronize()
    }
}

/**
 * Holds single JSON preference value
 */
internal class JSONPreference:StringPreference {
    internal init(prefName:String) {
        super.init(prefName: prefName, defaultValue: nil)
    }
    internal func set(_ json:[String:Any]) {
        set(try? Utils.JSONStringify(json as AnyObject))
    }
    

    internal func getAsMap() -> [String:Any]?{
        do {
            if let json = get() {
                return try Utils.parseJsonStringtoDictionary(json)
            } else {
                return nil
            }
        } catch {
            print(error)
            return nil
        }
    }
}



/**
 * Holds authorization manager Policy preference
 */
internal class PolicyPreference {
    
    private var value:PersistencePolicy
    private var prefName:String
    internal weak var idToken:TokenPreference?
    internal weak var accessToken:TokenPreference?
    

    init(prefName:String, defaultValue:PersistencePolicy, idToken:TokenPreference?, accessToken:TokenPreference?) {
        self.accessToken = accessToken
        self.idToken = idToken
        self.prefName = prefName
        if let rawValue = AppIDPreferences.sharedPreferences.value(forKey: prefName) as? String, let newValue = PersistencePolicy(rawValue: rawValue){
            self.value = newValue
        } else {
            self.value = defaultValue
        }
    }
    
    internal func get() -> PersistencePolicy {
        return self.value
    }

    internal func set(_ value:PersistencePolicy, shouldUpdateTokens:Bool) {
        self.value = value
        if(shouldUpdateTokens){
            self.accessToken!.updateStateByPolicy()
            self.idToken!.updateStateByPolicy()
        }
        AppIDPreferences.sharedPreferences.setValue(value.rawValue, forKey: prefName)
        AppIDPreferences.sharedPreferences.synchronize()
    }
}
/**
 * Holds authorization manager Token preference
 */
internal class TokenPreference {
    
    var runtimeValue:String?
    var prefName:String
    var persistencePolicy:PolicyPreference
    init(prefName:String, persistencePolicy:PolicyPreference){
        self.prefName = prefName
        self.persistencePolicy = persistencePolicy
    }
    

    internal func set(_ value:String) {
        runtimeValue = value
        if self.persistencePolicy.get() ==  PersistencePolicy.always {
            _ = SecurityUtils.saveItemToKeyChain(value, label: prefName)
        } else {
            _ = SecurityUtils.removeItemFromKeyChain(prefName)
        }
    }
    
    internal func get() -> String?{
        if (self.runtimeValue == nil && self.persistencePolicy.get() == PersistencePolicy.always) {
            return SecurityUtils.getItemFromKeyChain(prefName)
        }
        return runtimeValue
    }
    internal func updateStateByPolicy() {
        if (self.persistencePolicy.get() == PersistencePolicy.always) {
            if let unWrappedRuntimeValue = runtimeValue {
                _ = SecurityUtils.saveItemToKeyChain(unWrappedRuntimeValue, label: prefName)
            }
        } else {
            _ = SecurityUtils.removeItemFromKeyChain(prefName)
        }
    }
    
    internal func clear() {
        _ = SecurityUtils.removeItemFromKeyChain(prefName)
        runtimeValue = nil
    }
}
