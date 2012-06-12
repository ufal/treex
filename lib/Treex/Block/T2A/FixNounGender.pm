package Treex::Block::T2A::FixNounGender;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'generator_class' => ( is => 'rw', required => 1 );
has 'generator' => ( is => 'rw' );

sub process_start {
    my $self = shift;
    eval "use ".$self->generator_class;
    $self->set_generator(eval $self->generator_class."->new(); ")
        or log_fatal "Cannot initiate generator from class ".$self->generator_class;
    return;
}

sub process_anode {
    my ( $self, $anode ) = @_;

    my $gender;  # TODO: detected noun gender should be cached
    foreach my $form_info ($self->generator->forms_of_lemma($anode->lemma)) {
        if ( $form_info->get_tag =~ /^N.(.)/ ) {
            return if $gender and $gender ne $1;
            $gender = $1;
        }
        else {
            return;
        }
    }

    if ( ($anode->get_attr('morphcat/number')||'') eq 'P') {
        $anode->set_attr('morphcat/gender','.');
        return;
    }

    return if not $gender;

    #my $old_value = $anode->attr('morphcat/gender');
    #if ($old_value ne $gender) {
    #    print $anode->lemma."  old gender: $old_value new: $gender\n";
    #}

    $anode->set_attr('morphcat/gender', $gender);

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::FixNounGender


=head1 DESCRIPTION

1) Fill noun gender according to target-language morphology, regardless
the gender value resulting from the source language.

2) Disregard noun gender in plural.

=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
