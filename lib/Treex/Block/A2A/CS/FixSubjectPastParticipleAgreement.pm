package Treex::Block::A2A::CS::FixSubjectPastParticipleAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ($self->en($dep)
        && $self->en($dep)->afun && $self->en($dep)->afun eq 'Sb'
        && $g->{tag} =~ /^V[sp]/ && $d->{tag} =~ /^[NP]/
        && $dep->form !~ /^[Tt]o$/
        && ( $g->{gen} . $g->{num} ne $self->gn2pp( $d->{gen} . $d->{num} ) )
        )
    {

        my $do_fix = 1;
        if ( $dep->ord < $gov->ord ) {

            # subject before verb
            $do_fix = 1;
        }
        else {

            # subject after verb: this is a little suspicious
            my @preceding_children = $gov->get_children(
                {
                    preceding_only => 1
                }
            );
            foreach my $child (@preceding_children) {
                if (
                    (
                        $child->afun eq 'Sb'
                        ||
                        (   $self->en($child)
                            && $self->en($child)->afun eq 'Sb'
                        )
                    )
                    && $child->tag =~ /^[NP]/
                    && $child->form !~ /^[Tt]o$/
                    )
                {

                    # there probably already is another subject BEFORE the verb -- which is more reliable
                    $do_fix = 0;
                }
            }
        }

        if ($do_fix) {
            my $num = $d->{num};
            my $gen = $d->{gen};
            if ( $dep->is_member && $self->en($dep)->is_member ) {
                $num = 'P';
                $gen = 'T';

                # masculine animate if there is at least one such subject
                my $coap    = $dep->get_parent();
                my @members = $coap->get_children();
                foreach my $subject (@members) {
                    if ( $subject->tag =~ /^..M/ ) {
                        $gen = 'M';
                    }
                }
            }

            my $new_gn = $self->gn2pp( $gen . $num );

            $self->logfix1( $dep, "SubjectPastParticipleAgreement" );
            substr $g->{tag}, 2, 2, $new_gn;

            $self->regenerate_node( $gov, $g->{tag} );
            $self->logfix2($dep);
        }
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixSubjectPastParticipleAgreement - Fixing agreement
between subject and past participle.

=head1 DESCRIPTION

Past participle (Vs or Vp) gets gender and number from subject.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
