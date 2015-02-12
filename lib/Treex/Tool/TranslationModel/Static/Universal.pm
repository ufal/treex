package Treex::Tool::TranslationModel::Static::Universal;
use Treex::Core::Common;
use autodie;
use Class::Std;
use Readonly;
use Storable;
use PerlIO::gzip;
use List::Util qw(first);
use List::MoreUtils qw(any);
use Scalar::Util qw(weaken);

use Treex::Tool::TranslationModel::Static::Variant;

Readonly my $LOG2  => log(2);
Readonly my $USAGE => 'my $dict = Treex::Tool::TranslationModel::Static::Universal->new({file=>"$path_to/dict.pls.gz"});';

# Each instance of this class has its model...
my %model_of : ATTR;

# ...but those models are shared across all instances if loaded from the same file name
my %loaded_models;

# Filename of a model is a readonly attribute
my %file_of : ATTR( :init_arg<file> :get<file> );

sub BUILD {
    log_fatal('Incorrect number of arguments') if @_ != 3;
    my ( $self, $id, $arg_ref ) = @_;
    my $filename = $arg_ref->{'file'};
    log_fatal( 'Missing argument "file". Usage: ' . $USAGE )
        if !defined $filename;
    $file_of{$id} = $filename;

    # If this model has been loaded before, just reuse it
    return if defined( $model_of{$id} = $loaded_models{$filename} );

    log_fatal("Could not read file '$filename'.") if ( !-r $filename );

    #<<<
    my $model_ref
        = $filename =~ /.pls.gz$/ ? _load_from_storable($filename)
        : $filename =~ /.tsv$/    ? _load_from_tsv($filename, $arg_ref)
        : log_fatal("File $filename is neither *.pls.gz nor *.tsv!");
    #>>>
    $loaded_models{$filename} = $model_ref;
    $model_of{$id}            = $model_ref;
    weaken $loaded_models{$filename};

    #TODO if asked build additional hash structure in model
    #     for better performance of get_prob
    return;
}

sub aux_keys {
    my ($self) = @_;
    my $id = ident $self;
    return @{ $model_of{$id}{aux_keys} };
}

sub translations_of {
    my ( $self, $main_key, $arg_ref ) = @_;
    my $id            = ident $self;
    my $model_ref     = $model_of{$id};
    my @aux_key_names = $self->aux_keys();
    my @aux_keys      = map { $arg_ref->{$_} } @aux_key_names;
    log_fatal( "Model $file_of{$id} needs keys: " . join( ', ', @aux_key_names ) )
        if any { !defined $_ } @aux_keys;
    my $keys_string = join "\t", $main_key, @aux_keys;
    my $value = $model_ref->{$keys_string};
    return if !defined $value;
    my ( $limit, $min_prob, $min_cumulated ) = map { $arg_ref->{$_} } qw(limit min_prob min_cumulated_prob);
    return @{$value} if !$limit && !$min_prob;
    my @filtred = ();

    my $cumulated = 0;
    foreach my $variant ( @{$value} ) {
        last if $limit && @filtred + 1 > $limit;
        last if $min_prob && $variant->prob() < $min_prob;
        $cumulated += $variant->prob();
        last if $min_cumulated && $cumulated > $min_cumulated;
        push @filtred, $variant;
    }
    return @filtred;
}

sub prob_of {
    my ( $self, $value, $main_key, $arg_ref ) = @_;

    # TODO Regarding performance, it would be better to
    # return $model->{$keys_string}{$value};
    my @translations = $self->translations_of( $main_key, $arg_ref );
    my $variant = first { $_->value() eq $value } @translations;
    return if !$variant;
    return $variant->prob();
}

sub logprob_of {
    my $self = shift;
    my $prob = $self->prob_of(@_);
    return if !$prob;
    return log($prob) / $LOG2;
}

sub _load_from_storable : RESTRICTED {
    my ($filename) = @_;
    open my $IN, '<:gzip', $filename;
    my $model_ref = Storable::fd_retrieve($IN);
    log_fatal("Could not parse perl storable model: '$filename'.") if ( !defined $model_ref );
    close $IN;
    return $model_ref;
}

sub save_to_storable {
    my ( $self, $filename ) = @_;
    log_fatal('Invalid number of parameters.') if @_ != 2;
    my $id = ident $self;
    open my $OUT, '>:gzip', $filename;
    my $model_ref = $model_of{$id};
    Storable::nstore_fd( $model_ref, $OUT );
    close $OUT;
    $loaded_models{$filename} = $model_ref;
    return;
}

sub _load_from_tsv : RESTRICTED {
    my ( $filename, $arg_ref ) = @_;
    my $columns_ref = $arg_ref->{columns};
    log_fatal("No columns defined for loading model from $filename")
        if !defined $columns_ref;
    my @columns = @{$columns_ref};

    my ( $value_idx, $main_key_idx, $prob_idx );
    my @aux_key_names = ();
    for my $i ( 0 .. $#columns ) {
        my $col = $columns[$i];
        if    ( $col eq 'value' )    { $value_idx    = $i; }
        elsif ( $col eq 'main_key' ) { $main_key_idx = $i; }
        elsif ( $col eq 'prob' )     { $prob_idx     = $i; }
        else                         { push @aux_key_names, $col; }
    }
    log_fatal( "Columns 'value', 'main_key' and 'prob' must be present, but got :" . join ', ', @columns )
        if any { !defined $_ } ( $value_idx, $main_key_idx, $prob_idx );

    my %model;
    $model{aux_keys} = \@aux_key_names;

    open my $IN, '<:utf8', $filename;
    my $accept_sub = $arg_ref->{accept_line};

    #my $line = <$IN>;
    #if ($line =~ /^#/){}
    while ( my $line = <$IN> ) {
        chomp $line;
        next if $line eq '';
        next if $accept_sub && !$accept_sub->($line);
        my @fields = split "\t", $line;
        my @aux_keys = ();
        my ( $value, $main_key, $prob ) = ( undef, undef, undef );
        for my $i ( 0 .. $#columns ) {
            my $field = $fields[$i];
            if    ( $i == $value_idx )    { $value    = $field; }
            elsif ( $i == $main_key_idx ) { $main_key = $field; }
            elsif ( $i == $prob_idx )     { $prob     = $field; }
            else                          { push @aux_keys, $field; }
        }

        my $keys_string = join "\t", $main_key, @aux_keys;

        #my $variant = Treex::Tool::TranslationModel::Static::Translation_variant->new( { value => $value, prob => $prob } );
        my $variant = Treex::Tool::TranslationModel::Static::Variant->new( $value, $prob );
        my $variants_ref = $model{$keys_string};
        if ( !defined $variants_ref ) {
            $model{$keys_string} = [$variant];
        }
        else {

            #TODO if (!$need_sort && ...) {$needs_sort=1;}
            push @{$variants_ref}, $variant;
        }
    }
    close $IN;
    return \%model;
}

sub save_to_tsv {
    my ( $self, $filename, $arg_ref ) = @_;
    log_fatal('Invalid number of parameters.') if @_ < 2 or @_ > 3;
    my $id            = ident $self;
    my $model_ref     = $model_of{$id};
    my @aux_key_names = $self->aux_keys();

    open my $OUT, '>:utf8', $filename;

    if ( $arg_ref->{header} ) {
        my $value_name    = $arg_ref->{value_name}    || 'value';
        my $main_key_name = $arg_ref->{main_key_name} || 'main_key';
        my $header = join "\t", $main_key_name, @aux_key_names, $value_name, 'prob';
        print {$OUT} '#' . $header . "\n";
    }

    while ( my ( $keys_string, $translations_ref ) = each %{$model_ref} ) {
        next if $keys_string eq 'aux_keys';
        foreach my $variant ( @{$translations_ref} ) {
            print {$OUT} "$keys_string\t$variant\t" . $variant->prob() . "\n";
        }
    }
    close $OUT;
    return;
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::TranslationModel::Static::Universal - universal interface to a probabilistic dictionary stored in a *.pls.gz file

=head1 VERSION

0.01

=head1 SYNOPSIS

 use Treex::Tool::TranslationModel::Static::Universal;

 # Load model describing probability of Czech formeme given English formeme
 my $formeme_dict = Treex::Tool::TranslationModel::Static::Universal->new({file=>"$path_to/Ftd_given_Fsd.pls.gz"});
  
 print join(', ', $formeme_dict->translations_of('n:for+X')), "\n";
 #>n:pro+4, n:na+4, n:2, n:za+4, n:4, n:1, n:k+3,... 
 
 my @translations = $formeme_dict->translations_of('n:for+X', {min_prob=>0.01});
 foreach my $tr (@translations){
     print join("\t", $tr, $tr->prob()), "\n";
 }
 #>n:pro+4  0.2943
 #>n:na+4   0.0968
 #>n:2      0.0944
 #>n:za+4   0.0901



 # Load model for Czech formeme given English formeme and English parent lemma
 my $formeme_valency_dict = Treex::Tool::TranslationModel::Static::Universal->new({file=>"$path_to/Ftd_given_Fsd_Lsg.pls.gz"});
 
 print join(', ', $formeme_valency_dict->aux_keys()), "\n";
 #>Lsg
 
 foreach my $tr ($formeme_valency_dict->translations_of('n:for+X', {Lsg=>'look', limit=>2})){
     print join("\t", $tr, $tr->logprob()), "\n";
 }
 #>n:4 -0.551099048854872
 #>n:1 -3.18836456914626



 # Load some strange translational model 
 my $strange_dict = Treex::Tool::TranslationModel::Static::Universal->new({file=>"$path_to/Ltd_given_Lsd_Fsd_Lsg_Fsg_Ltg_Fsg.pls.gz"});

 print join(', ', $strange_dict->aux_keys()), "\n";
 #>Fsd, Lsd, Fsg, Lsg, Ltg, Fsg
 
 my $probability = $strange_dict->prob_of('budoucnost', 'future',
    {Fsd=>'n:for+X', Lsg=>'look', Fsg=>'v:fin', Ltg=>'těšit_se', Fsg=>'v:fin' });

=head1 DESCRIPTION

This class serves as a universal interface to a probabilistic dictionary.
As for generalization, we define probabilistic dictionary as a set of entries
which are represented by (n+3)-tuples
C<(main_key, aux_key_1, aux_key_2, ..., aux_key_n, value, prob)>.
The C<prob> is a probability of C<value> given
C<(main_key, aux_key_1, aux_key_2, ..., aux_key_n)>.

Usually  C<main_key> represents the term we want to translate
and C<value> represents the translation. Optionally, auxiliary keys can be used,
as showed in the synopsis example above.

=head2 CONSTRUCTOR

=over

=item my $dict = Treex::Tool::TranslationModel::Static::Universal->new({file=>"$path_to/file.pls.gz"})

Loads a dictionary from a gzipped Perl Storable file
(L<http://search.cpan.org/perldoc?Storable>).


=item my $dict = Treex::Tool::TranslationModel::Static::Universal->new({file=E>"$path_to/file.tsv", ...})

Loads a dictionary from a *.tsv files. This form of constructor is used mainly
for building new *pls.gz file (by subsequent L<save_to_storable> method call).  

In a *.tsv file, each line is one entry with columns separeted by tabs.
Additional argument C<columns> MUST be given to specify the order of columns.
For example:

 my $dict = Treex::Tool::TranslationModel::Static::Universal->new({
     file    => "$path_to/file.tsv",
     columns => [qw(main_key value prob)]     
 });

This is the minimalistic dictionary structure (no aux keys), so columns
main_key, value and prob must be always specified. Names of other columns
are names of aux keys - you can choose it as you like - those names will
serve as keys in C<$arg_ref> hash for methods L<translations_of>,
L<prob_of> and L<logprob_of>.

If you don't want some lines of *.tsv file to be used in a dictionary, you can
specify C<accept_line> argument. This is a sub reference that return some true
value for lines (its first and only argument) that should be used in a dictionary.
For example:

 my $dict2 = Treex::Tool::TranslationModel::Static::Universal->new(
    {
        file        => $TSV_DIR . '/prob_Ftd_given_Fsd_Lsg.tsv',
        columns     => [qw(main_key Lsg value prob)],
        # Raw counts are in a comment in the last (5th) column of line.
        # Disregard entries that appeared in the training data only once.
        accept_line => sub { $_[0] !~ m|#\(1/|; },
    }
 );

=back

=head2 METHODS

=over

=item $dict->translations_of($main_key, $arg_ref)

Returns an array of translation variants for a given C<$main_key>
(and aux keys specified in C<$arg_ref>). Besides specifying aux keys, with
C<$arg_ref> you can also specify options:

=over

=item limit

Return at most C<limit> translation variants.

=item min_prob  

Don't return translation variants with lower probability than C<min_prob>.

=item min_cumulated_prob

Don't return more variants than is needed for exceeding

=back

Translation variants are actually instances of
L<Treex::Tool::TranslationModel::Static::Variant|Treex::Tool::TranslationModel::Static::Variant> class,
so in string context it is evaluated as a value, but you can use methods of this
object ($variant->prob() or $variant->logprob()) to get its probability.

=item $dict->prob_of($main_key, $value, $arg_ref)

Returns C<P($value | $main_key, aux_key_1, ..., aux_key_n)>.
Aux keys are specified in C<$arg_ref> hash.

=item $dict->logprob_of($main_key, $value, $arg_ref)

Returns C<log P($value | $main_key, aux_key_1, ..., aux_key_n)>.
Aux keys are specified in C<$arg_ref> hash.

=item $dict->aux_keys( )

Returns an array with names of aux keys.

=item $dict->save_to_storable( 'filename.pls.gz' )

Saves the dictionary into the given gzipped Perl Storable file.

=item $dict->save_to_tsv( 'filename.tsv', $arg_ref )

Saves the dictionary into the *.tsv file.
This method serves mainly for debugging or export.
Columns are always saved in the same order:
C<main_key, aux_key_1, ... , aux_key_n, value, prob>.

=item $dict->get_file( )

From which filename was this dictionary loaded?

=back

=head1 TODO

=over

=item * Better performance of prob_of by building additional hash structures.

=back

=head1 AUTHOR

Martin Popel

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
