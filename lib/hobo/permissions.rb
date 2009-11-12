module Hobo
  
  module Permissions
    
    class UndefinedAccessError < StandardError; end;
    class PermissionDeniedError < StandardError; end;
    
    def self.included(klass)
      klass.class_eval do
	    #Hobo::Permissions::Associations.enable
        extend ClassMethods
        
        alias_method_chain :create, :permission_check
        alias_method_chain :update, :permission_check
        alias_method_chain :destroy, :permission_check

        attr_accessor :acting_user, :origin, :origin_attribute, :exempt_from_edit_checks
        
        define_callbacks :after_user_new
      end
    end
        
    module ClassMethods
            
      def user_find(user, *args)
        record = find(*args)
        yield(record) if block_given?
        record.user_view user
        record
      end


      def user_new(user, attributes={})
        new(attributes) do |r|
          r.set_creator user
          yield r if block_given? 
          r.user_view(user)
          r.send :callback, :after_user_new
        end
      end


      def user_create(user, attributes={}, &block)
        if attributes.is_a?(Array)
          attributes.map { |attrs| user_create(user, attrs) }
        else
          record = user_new(user, attributes, &block)
          record.user_save(user)
          record
        end
      end


      def user_create!(user, attributes={}, &block)
        if attributes.is_a?(Array)
          attributes.map { |attrs| user_create(user, attrs) }
        else
          record = user_new(user, attributes, &block)
          record.user_save!(user)
          record
        end
      end
      
      def viewable_by?(user, attribute=nil)
        new.viewable_by?(user, attribute)
      end
      
    end
    
    
    # --- Hook ActiveRecord CRUD actions --- #
    
    
    def permission_check_required?
      acting_user
    end
        
    def create_with_permission_check(*args, &b)
      if permission_check_required?
        create_permitted? or raise PermissionDeniedError, "#{self.class.name}#create"
      end
      create_without_permission_check(*args, &b)
    end

    def update_with_permission_check(*args)
      if permission_check_required?
        update_permitted? or raise PermissionDeniedError, "#{self.class.name}#update"
      end
      update_without_permission_check(*args)
    end

    def destroy_with_permission_check
      if permission_check_required?
        destroy_permitted? or raise PermissionDeniedError, "#{self.class.name}#.destroy"
      end
      
      destroy_without_permission_check
    end
    
    # -------------------------------------- #
    

    # --- Permissions API --- #
    
    
    def with_acting_user(user)
      old = acting_user
      self.acting_user = user
      result = yield
      self.acting_user = old
      result
    end
    
    def user_save(user)
      with_acting_user(user) { save }
    end
        
    def user_save!(user)
      with_acting_user(user) { save! }
    end

    def user_destroy(user)
      with_acting_user(user) { destroy }
    end
        
    def user_view(user, attribute=nil)
      raise PermissionDeniedError unless viewable_by?(user, attribute)
    end
        
    def user_update_attributes(user, attributes)
      with_acting_user(user) do
        self.attributes = attributes
        save
      end
    end

    def user_update_attributes!(user, attributes)
      with_acting_user(user) do
        self.attributes = attributes
        save!
      end
    end
    
    def creatable_by?(user)
      with_acting_user(user) { create_permitted? }
    end

    def updatable_by?(user)
      with_acting_user(user) { update_permitted? }
    end
    
    def destroyable_by?(user)
      with_acting_user(user) { destroy_permitted? }
    end
    
    def method_callable_by?(user, method)
      permission_method = "#{method}_permitted?"
      respond_to?(permission_method) && with_acting_user(user) { send(permission_method) }
    end
    
    def viewable_by?(user, attribute=nil)
      if attribute
        attribute = attribute.to_s.sub(/\?$/, '').to_sym
        return false if attribute && self.class.never_show?(attribute)
      end
      with_acting_user(user) { view_permitted?(attribute) }
    end
    
    
    def editable_by?(user, attribute=nil)
      return false if attribute_protected?(attribute)
      
      return true if exempt_from_edit_checks?

      # Can't view implies can't edit
      return false unless viewable_by?(user, attribute)
      
      if attribute
        attribute = attribute.to_s.sub(/\?$/, '').to_sym

        # Try the attribute-specic edit-permission method if there is one
        if respond_to?(meth = "#{attribute}_edit_permitted?")
          with_acting_user(user) { send(meth) } 
        end
      
        # No setter = no edit permission
        return false if !respond_to?("#{attribute}=")

        refl = self.class.reflections[attribute.to_sym]
        if refl && refl.macro != :belongs_to # a belongs_to is handled the same as a regular attribute
          return association_editable_by?(user, refl)
        end
      end

      with_acting_user(user) { edit_permitted?(attribute) }
    end
    
    
    def attribute_protected?(attribute)
      attribute = attribute.to_s
      
      return true if attributes_protected_by_default.include? attribute
      
      if self.class.accessible_attributes
        return true if !self.class.accessible_attributes.include?(attribute)
      elsif self.class.protected_attributes
        return true if self.class.protected_attributes.include?(attribute)
      end
      
      # Readonly attributes can be set on creation but not thereafter
      return self.class.readonly_attributes.include?(attribute) if !new_record? && self.class.readonly_attributes
      
      false
    end
    
    
    def association_editable_by?(user, reflection)      
      # has_one and polymorphic associations are not editable (for now)
      return false if reflection.macro == :has_one || reflection.options[:polymorphic]
      
      return false unless reflection.options[:accessible]
            
      record = if (through = reflection.through_reflection)
                 # For edit permission on a has_many :through,
                 # the user needs create+destroy permission on the join model
                 send(through.name).new_candidate
               else
                 # For edit permission on a regular has_many,
                 # the user needs create/destroy permission on the member model
                 send(reflection.name).new_candidate
               end
      record.creatable_by?(user) && record.destroyable_by?(user)
    end
    
    # ----------------------- #
    
    
    # --- Permission Declaration Helpers --- #
    
    def only_changed?(*attributes)
      attributes = attributes.map do |attr|
        with_attribute_or_belongs_to_keys(attr) { |a, ftype| ftype ? [a, ftype] : a }
      end.flatten
      
      changed.all? { |attr| attributes.include?(attr) }
    end
    
    def none_changed?(*attributes)
      attributes = attributes.map do |attr|
        with_attribute_or_belongs_to_keys(attr) { |a, ftype| ftype ? [a, ftype] : a }
      end.flatten
      
      attributes.all? { |attr| !changed.include?(attr) }
    end

    def any_changed?(*attributes)
      attributes.any? do |attr|
        with_attribute_or_belongs_to_keys(attr) do |a, ftype|
          if ftype
            changed.include?(a) || changed.include?(ftype)
          else
            changed.include?(a)
          end
        end
      end
    end

    def all_changed?(*attributes)
      attributes = prepare_attributes_for_change_helpers(attributes)
      attributes.all? do |attr|
        with_attribute_or_belongs_to_keys(attr) do |a, ftype|
          if ftype
            changed.include?(a) || changed.include?(ftype)
          else
            changed.include?(a)
          end
        end
      end
    end    
    
    def with_attribute_or_belongs_to_keys(attribute)
      if (refl = self.class.reflections[attribute.to_sym]) && refl.macro == :belongs_to
        if refl.options[:polymorphic]
          yield refl.primary_key_name, refl.options[:foreign_type]
        else
          yield refl.primary_key_name, nil
        end
      else
        yield attribute.to_s, nil
      end
    end
      
    
    
    # -------------------------------------- #
    
    
    # --- Default *_permitted? methods --- #
    
    # Conservative default permissions #
    def create_permitted?;  false end
    def update_permitted?;  false end
    def destroy_permitted?; false end
    
    # Allow viewing by default
    def view_permitted?(attribute) true end
      
    # By default, attempt to derive edit permission from create/update permission
    def edit_permitted?(attribute)
      unknownify_attribute(attribute) if attribute
      new_record? ? create_permitted? : update_permitted?
    rescue UndefinedAccessError
      # The permission is dependent on the unknown value
      # so this attribute is not editable
      false
    ensure
      deunknownify_attribute(attribute) if attribute
    end
  
  
    # Add some singleton methods to +record+ to give the effect that +attribute+ is unknown. That is,
    # attempts to access the attribute will result in a UndefinedAccessError
    def unknownify_attribute(attr)
      metaclass.class_eval do
        define_method attr do
          raise UndefinedAccessError
        end
      end
      
      if (refl = self.class.reflections[attr.to_sym]) && refl.macro == :belongs_to
        # A belongs_to -- also unknownify the underlying fields
        unknownify_attribute refl.primary_key_name
        unknownify_attribute refl.options[:foreign_type] if refl.options[:polymorphic]
      else
        # A regular field -- hack the dirty tracking methods
        
        metaclass.class_eval do
        
          define_method "#{attr}_change" do
            raise UndefinedAccessError
          end
        
          define_method "#{attr}_was" do
            read_attribute attr
          end
        
          define_method "#{attr}_changed?" do
            true
          end

          def changed?
            true
          end
      
          define_method :changed do
            changed_attributes.keys | [attr.to_s]
          end
      
          def changes
            raise UndefinedAccessError
          end
        
        end
      end
    end
    
    # Best. Name. Ever
    def deunknownify_attribute(attr)
      attr = attr.to_sym
      
      metaclass.send :remove_method, attr
      
      if (refl = self.class.reflections[attr]) && refl.macro == :belongs_to
        # A belongs_to -- restore the underlying fields
        deunknownify_attribute refl.primary_key_name
        deunknownify_attribute refl.options[:foreign_type] if refl.options[:polymorphic]
      else
        # A regular field -- restore the dirty tracking methods
        ["#{attr}_change", "#{attr}_was", "#{attr}_changed?", :changed?, :changed, :changes].each do |m|
          metaclass.send :remove_method, m.to_sym
        end
      end
    end
  end
  
end
      
