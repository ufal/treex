package Treex::Tool::Coreference::NodeFilter::Noun;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter::Utils qw/ternary_arg/;

with 'Treex::Tool::Coreference::NodeFilter';

has 'args' => (is => "ro", isa => "HashRef", default => sub {{}});

sub is_candidate {
    my ($self, $tnode) = @_;
    return is_3rd_pers($tnode, $self->args);
}

sub is_sem_noun {
    my ($tnode, $args) = @_;
    $args //= {};
    
    return if !_is_sem_noun_all($tnode, $args);
    if ($tnode->language eq 'cs') {
        return if !is_sem_noun_cs($tnode, $args);
    }
    return 1;
}

sub is_sem_noun_cs {
    my ($tnode, $args) = @_;
    
    my $anode = $tnode->get_lex_anode;
    return (!$anode || ($anode->tag !~ /^[CJRTDIZV]/));
}    

sub _is_sem_noun_all {
    my ($tnode, $args) = @_;

    my $third_pers = !$tnode->gram_person || ($tnode->gram_person !~ /1|2/);
    my $arg_third_pers = $args->{third_pers} // 0;
    return 0 if !ternary_arg($arg_third_pers, $third_pers);

    return (defined $tnode->gram_sempos && ($tnode->gram_sempos =~ /^n/));
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::NodeFilter::Noun

=head1 DESCRIPTION

A filter for nodes that are semantic nouns.

=head1 METHODS

=over

=item my $bool = is_sem_noun($tnode, $args)

Returns whether the input C<$tnode> is a semantic noun or not.
Using the following flags, one can specify the condition:

=over
=item third_pers - 0: both in and not in third person, 1: in third person, -1: not in third person
=back

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
