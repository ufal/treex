package Treex::Block::A2T::PT::FixFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if ($tnode->formeme eq "adj:attr") {
        if ($tnode->parent->formeme =~ /n:/) {
            if ($tnode->precedes($tnode->parent)) {
                $tnode->set_formeme("adj:prenom");
            } else {
                $tnode->set_formeme("adj:postnom");
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::PT::FixFormeme


