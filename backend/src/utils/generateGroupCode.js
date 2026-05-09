const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const buildCode = () => {
  let suffix = '';
  for (let index = 0; index < 5; index += 1) {
    suffix += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  return `TL-${suffix}`;
};

const generateUniqueGroupCode = async (GroupModel) => {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const groupCode = buildCode();
    const exists = await GroupModel.exists({ groupCode });
    if (!exists) return groupCode;
  }

  throw new Error('Could not generate a unique group code.');
};

module.exports = {
  generateUniqueGroupCode,
};
