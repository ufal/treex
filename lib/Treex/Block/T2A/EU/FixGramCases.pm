package Treex::Block::T2A::EU::FixGramCases;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

#### TODO: Exceptions


sub process_tnode {
    my ( $self, $tnode ) = @_;

    my @gramCases = grep {defined ($_->src_tnode) && $_->src_tnode->formeme =~ /:(subj|obj)/} $tnode->get_children();
    my $transitive = $self->is_transitive($tnode->src_tnode);
    
    foreach my $child (@gramCases) {
	$child->set_formeme("$1:[erg]+X") if ($transitive && $child->src_tnode->formeme =~ /(.*):subj/);
	$child->set_formeme("$1:[abs]+X") if ((! $transitive && $child->src_tnode->formeme =~ /(.*):subj/) || $child->src_tnode->formeme =~ /(.*):obj/);
	$child->set_formeme("$1:[dat]+X") if ($child->src_tnode->formeme =~ /(.*):obj/ && ($child->gram_person || '3') ne '3');
    }
}

sub is_transitive {
    my ($self, $tnode) = @_;

    return grep {$_->formeme =~ /:obj/} $tnode->get_children() if ($tnode);

    return 0;
}

sub is_bitransitive {
    my ($self, $tnode) = @_;

    my @objects = grep {$_->formeme =~ /:obj/} $tnode->get_children() if ($tnode);

    return 1 if ($#objects >= 1);
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EU::GramCases

=head1 DESCRIPTION



=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by IXA Group, University of the Basque Country (UPV/EHU)
