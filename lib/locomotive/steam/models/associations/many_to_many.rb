module Locomotive::Steam
  module Models

    class ManyToManyAssociation < ReferencedAssociation

      def __load__
        key = @repository.k(:_id, :in)

        @repository.local_conditions[key] = @entity[__target_key__] || []

        # use order_by from options as the default one for further queries
        @repository.local_conditions[:order_by] = @options[:order_by] unless @options[:order_by].blank?

        # all the further calls (method_missing) will be delegated to @repository
        @repository
      end

      # Liquid calls .to_liquid on the resolved variable before iterating.
      # Without this method, to_liquid falls through method_missing into
      # repository.to_liquid which returns a ContentEntryCollection that
      # fetches entries in content type default order, discarding the
      # stored ID array order. By defining to_liquid directly, we
      # materialize entries in the correct order and return a plain array.
      # Array#to_liquid returns self, so Liquid iterates it directly.
      def to_liquid
        __call_block_once__
        _reorder_by_target_ids(__load__.all.to_a)
      end

      def method_missing(name, *args, &block)
        __call_block_once__

        if name == :each && block
          entries = __load__.all.to_a
          _reorder_by_target_ids(entries).each(&block)
        elsif name == :to_a
          _reorder_by_target_ids(__load__.all.to_a)
        else
          __load__.try(:send, name, *args, &block)
        end
      end

      def __serialize__(attributes)
        attributes[__target_key__] = attributes[__name__].try(:map, &:_id)

        attributes.delete(__name__)
      end

      def __target_key__
        :"#{__name__.to_s.singularize}_ids"
      end

      private

      def _reorder_by_target_ids(entries)
        ids = @entity[__target_key__] || []
        return entries if ids.empty?

        id_index = {}
        ids.each_with_index { |id, i| id_index[id.to_s] = i }
        entries.sort_by { |e| id_index[e._id.to_s] || ids.size }
      end

    end

  end
end
