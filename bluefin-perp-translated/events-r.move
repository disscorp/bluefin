module bluefin::events {
    struct VaultStoreAdminUpdateEvent has copy, drop {
        vault_store: sui::object::ID,
        admin: address,
    }
    
    struct VaultBankManagerUpdateEvent has copy, drop {
        vault_store: sui::object::ID,
        bank_manager: address,
    }
    
    struct VaultBankAccountCreationEvent has copy, drop {
        vault_store: sui::object::ID,
        bank_account: address,
    }
    
    struct VaultSubAccountEvent has copy, drop {
        vault_store: sui::object::ID,
        vault_bank_account: address,
        sub_account: address,
        status: bool,
    }
    
    public(friend) fun emit_vault_bank_account_created_event(vault_store_id: sui::object::ID, bank_account_addr: address) {
        let event = VaultBankAccountCreationEvent{
            vault_store  : vault_store_id, 
            bank_account : bank_account_addr,
        };
        sui::event::emit<VaultBankAccountCreationEvent>(event);
    }
    
    public(friend) fun emit_vault_bank_manager_udpdate_event(vault_store_id: sui::object::ID, bank_manager_addr: address) {
        let event = VaultBankManagerUpdateEvent{
            vault_store  : vault_store_id, 
            bank_manager : bank_manager_addr,
        };
        sui::event::emit<VaultBankManagerUpdateEvent>(event);
    }
    
    public(friend) fun emit_vault_store_admin_udpdate_event(vault_store_id: sui::object::ID, admin_addr: address) {
        let event = VaultStoreAdminUpdateEvent{
            vault_store : vault_store_id, 
            admin       : admin_addr,
        };
        sui::event::emit<VaultStoreAdminUpdateEvent>(event);
    }
    
    public(friend) fun emit_vault_sub_account_event(
		vault_store_id: sui::object::ID,
		vault_bank_account_addr: address,
		sub_account_addr: address,
		sub_account_status: bool
	) {
        let event = VaultSubAccountEvent{
            vault_store        : vault_store_id, 
            vault_bank_account : vault_bank_account_addr, 
            sub_account        : sub_account_addr, 
            status             : sub_account_status,
        };
        sui::event::emit<VaultSubAccountEvent>(event);
    }
}
