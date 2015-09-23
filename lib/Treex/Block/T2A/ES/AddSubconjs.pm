package Treex::Block::T2A::ES::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubconjs';

sub preprocess {
    my ( $self, $t_node ) = @_;
    
    #subjunktiboetan lema aldatu eta "que+..." jartzeko
    my $parent = $t_node->parent();

    my @children = grep {$_->t_lemma eq 'que'} $t_node->get_children();
    if (($parent->formeme || "") =~ /^n:.+/ 
	and ($t_node->formeme || "") =~ /^v:.+/ 
	and ($parent->ord < $t_node->ord)
	and ($t_node->formeme !~ /^v:.+\+.+/)
	and !(@children))
    {
	my $formeme = $t_node->formeme =~ /^v:(.+)/;
	$formeme = 'v:que+' . $1;
	$t_node->set_formeme($formeme);
    }

};
1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddSubconj

=head1 DESCRIPTION


=head1 AUTHORS


=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
