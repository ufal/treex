package Treex::Block::Depfix::EN2CS::MLFix;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Block::Depfix::MLFix';

use Treex::Tool::Depfix::CS::FormGenerator;
use Treex::Tool::Depfix::MaxEntModel;

has c_cas_config_file => ( is => 'rw', isa => 'Str', required => 1 );
has c_cas_model_file => ( is => 'rw', isa => 'Str', required => 1 );

override '_build_form_generator' => sub {
    my ($self) = @_;

    return Treex::Tool::Depfix::CS::FormGenerator->new();
};

override '_load_models' => sub {
    my ($self) = @_;

    $self->_models->{c_cas} = Treex::Tool::Depfix::MaxEntModel->new(
        config_file => $self->c_cas_config_file,
        model_file  => $self->c_cas_model_file,
    );
    
    return;
};

my @tag_parts = qw(pos sub gen num cas pge pnu per ten gra neg voi);

override 'fill_language_specific_features' => sub {
    my ($self, $features, $child, $parent) = @_;

    # tag parts
    my @child_tag_split  = split //, $child->tag;
    my @parent_tag_split = split //, $parent->tag;
    for (my $i = 0; $i < scalar(@tag_parts); $i++) {
        my $part = $tag_parts[$i];
        $features->{"c_tag_$part"} = $child_tag_split[$i];
        $features->{"p_tag_$part"} = $parent_tag_split[$i];
    }

    return;
};

override '_predict_new_tag' => sub {
    my ($self, $child, $model_predictions) = @_;

    my $message = 'MLFix c_cas ' . $child->tag . ' (';

    my $max = 0;
    my $max_case = '-';
    foreach my $cas (keys %{$model_predictions->{c_cas}} ) {
        $message .= $cas .':'. $model_predictions->{c_cas}->{$cas} . ' ';
        if ( $model_predictions->{c_cas}->{$cas} > $max ) {
            $max = $model_predictions->{c_cas}->{$cas};
            $max_case = $cas;
        }
    }

    $message .= ') ';

    if ( $max_case =~ /[1-7]/ ) {
        my $tag = $child->tag;
        substr $tag, 4, 1, $max_case;
        $self->fixLogger->logfixNode($child, "$message -> $tag");
        return $tag;
    } else {
        return;
    }
};


1;

=head1 NAME 

Depfix::EN2CS::MLFix -- fixes errors using a machine learned correction model,
with EN as the source language and CS as the target language

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

