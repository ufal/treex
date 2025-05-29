package Treex::Tool::UMR::GrammatemeSetter;
use Moose::Role;

requires qw{ tag_regex translate };

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

        my $set_attr = "set_$IMPLEMENTATION{$gram}{attr}";
        my $value = $orig_node->${ \$IMPLEMENTATION{$gram}{gram} };
        if (! $value
            && ! grep $_->tfa, $orig_node->root->descendants # Not in PDT.
        ) {
            if (my $anode = $orig_node->get_lex_anode) {
                my $tag = $self->tag_regex($gram);
                # TODO: "jejich" is P9XXXXP3, i.e. the number is X,
                # but there is possessor's plural!
                ($value) = $anode->tag =~ $tag;
                $value = $self->translate($gram, $value) if $value;
            }
            return unless $value;
        }
        $value = $T2U{$gram}{$value};
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
