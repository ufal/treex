package Treex::Block::A2A::CS::FixFirstWordCapitalization;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', required => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
has 'log_to_console'  => ( is => 'rw', isa => 'Bool', default => 1 );

use Treex::Tool::Depfix::CS::FixLogger;

my $fixLogger;

sub process_start {
    my $self = shift;
    
    $fixLogger = Treex::Tool::Depfix::CS::FixLogger->new({
        language => $self->language,
        log_to_console => $self->log_to_console
    });

    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $a_root     = $zone->get_atree;
    my $first_node = $a_root->get_descendants( { first_only => 1 } );
    my $first_char = substr( $first_node->form, 0, 1 );

    # if sentence begins in lowercase
    if ( $first_char ne uc($first_char) ) {

        # check beginning of en sentence
        my $en_root = $zone->get_bundle->get_tree(
            $self->source_language, 'a', $self->source_selector
        );
        my $first_en_node = $en_root->get_descendants( { first_only => 1 } );
        my $first_en_char = substr( $first_en_node->form, 0, 1 );

        if ( $first_en_char eq uc($first_en_char) ) {

            # en sentence begins in uppercase
            # -> cs sentences should probably also begin in uppercase
            $fixLogger->logfix1($first_node, "FirstWordCapitalization");
            $first_node->set_form(
                uc($first_char) . substr( $first_node->form, 1 )
            );
            $fixLogger->logfix2($first_node);
        }

        # else: keep as it is (both CS and EN sentence begin in lowercase)
    }

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixFirstWordCapitalization - correct capitalization of
first word in sentence

=head1 DESCRIPTION

The first word of a sentence should be capitalized (unless the first word of the
aligned sentence is lowercased).

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
