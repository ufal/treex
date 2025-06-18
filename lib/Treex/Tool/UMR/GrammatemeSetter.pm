package Treex::Tool::UMR::GrammatemeSetter;
use Moose::Role;

requires qw{ tag_regex translate is_valid_tag };

{   my %IMPLEMENTATION = (person => {gram => 'gram_person',
                                     attr => 'entity_refperson'},
                          number => {gram => 'gram_number',
                                     attr => 'entity_refnumber'});
    my %T2U = (person => {1 => '1st',
                          2 => '2nd',
                          3 => '3rd'},
               number => {sg => 'singular',
                          pl => 'plural'});
    sub maybe_set {
        my ($self, $gram, $unode, $orig_node) = @_;
        my $get_attr = $IMPLEMENTATION{$gram}{attr};
        return if $unode->$get_attr;

        my $value = ($orig_node->gram_sempos // "") =~ /^n/
                  ? $orig_node->${ \$IMPLEMENTATION{$gram}{gram} }
                  : undef;
        if (! $value
            && ! grep $_->tfa, $orig_node->root->descendants # Not in PDT.
        ) {
            if (my $anode = $orig_node->get_lex_anode) {
                my $tag = $self->tag_regex($gram);
                return unless $self->is_valid_tag($tag);

                ($value) = $anode->tag =~ $tag;
                $value = $self->translate($gram, $value) if $value;
            }
            return unless $value;
        }
        $value = $T2U{$gram}{$value};
        my $set_attr = "set_$IMPLEMENTATION{$gram}{attr}";
        $unode->$set_attr($value) if $value;
        return
    }
}


=head1 NAME

Treex::Block::T2U::GrammatemeSetter - a role to implement grammateme
propagation over coreference based on grammatemes of the antecedent or its
morphological information.

=cut

__PACKAGE__
