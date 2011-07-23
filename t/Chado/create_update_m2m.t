use Test::Exception;
use aliased 'Modware::DataSource::Chado';
use Modware::Build;
use Test::More qw/no_plan/;
use Digest::MD5 qw/md5/;

my $build = Modware::Build->current;
Chado->connect( $build->connect_hash );

my ($expression, $image);
use_ok('TestExpression');
subtest 'Test::Chado::Expression' => sub {
    lives_ok {
        $expression = Test::Modware::Chado::Expression->create(
            checksum   => md5('exp2'),
            name       => 'exp2',
            uniquename => 'exp2'
        );
    }
    'creates a new expression in database';

    lives_ok {
        $expression->images(
            Test::Modware::Chado::Expression::Image->new(
                type => 'png',
                uri  => 'http://image.com',
                data => 'image_data'
            )
        );
    }
    'added one image';

    lives_ok {
        $expression->images(
            Test::Modware::Chado::Expression::Image->new(
                type => 'tiff',
                uri  => 'http://image.com',
                data => 'tiff data'
            )
        );
    }
    'added another image';

    is( $expression->images->size, 0, 'has unsaved images' );

    my $exp_db;
    lives_ok { $exp_db = $expression->save } 'is saved along with two images';

    is( $exp_db->exp_images->size, 2,
        'has two exp_images through has_many associations' );

    isa_ok($_, 'Test::Modware::Chado::ExpressionImage') for $exp_db->exp_images;
    is( $exp_db->images->size, 2,
        'has two images through many_to_many assoications' );

    isa_ok($_,'Test::Modware::Chado::Expression::Image') for $exp_db->images;

    is_deeply( [ sort { $a cmp $b } map { $_->type } $exp_db->images ],
        [qw/png tiff/], 'has images with correct types' );
};

subtest 'Test::Chado::Expression returns iterator in scalar context' => sub {
    my $itr = $exp_db->images;
    isa_ok( $itr, 'Modware::Iterator::Chado::BCS::Association' );
    while ( my $row = $itr->next ) {
        isa_ok( $row, 'Test::Chado::Expression::Image' );
    }
};

subtest 'Test::Chado::Expression' => sub {
    my $image1;
    lives_ok {
        $image1 = $expression->images->add_new(
            type => 'gif',
            uri  => 'http://gif.com',
            data => 'gif data'
        );
    }
    'adds a new image';
    isa_ok( $image1, 'Test::Chado::Expression::Image' );
    is( $image1->new_record, 1, 'image is not yet saved in the database' );
    lives_ok { $expression->save } 'is saved with the new image';
    is( $expression->images->size, 3, 'image is saved in the database' );
};

subtest 'Test::Chado::Expression' => sub {
    my $image2;
    lives_ok {
        $image2 = $expression->images->create(
            type => 'gif45',
            uri  => 'http://gif45.com',
            data => 'gif45 data'
        );
    }
    'creates a new image';
    isa_ok( $image2, 'Test::Chado::Expression::Image' );
    isnt( $image2->new_record, 1, 'image is saved in the database' );
    is( $expression->images->size, 4, 'has 4 images saved in the database' );
};

subtest 'Test::Chado::Expression::Image' => sub {
	lives_ok {
	$image = Test::Chado::Expression::Image->create(
		type => 'png98', 
		uri => 'https://png98.com', 
		data => 'png98 data'
	)} 
	'creates a new image';
};
